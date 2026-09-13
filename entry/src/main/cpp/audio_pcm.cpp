#include "napi/native_api.h"
#include "multimedia/player_framework/native_avsource.h"
#include "multimedia/player_framework/native_avdemuxer.h"
#include "multimedia/player_framework/native_avcodec_audiocodec.h"
#include "multimedia/player_framework/native_avbuffer.h"
#include "pcm_resampler.h"
#include <atomic>
#include <chrono>
#include <cstring>
#include <fcntl.h>
#include <memory>
#include <mutex>
#include <string>
#include <sys/stat.h>
#include <unordered_map>
#include <unistd.h>

namespace {
constexpr uint64_t kMaxSamples = 16000ULL * 30 * 60;
struct Job {
    std::string id, source, destination, error;
    std::atomic<bool> cancelled{false};
    bool outputCreated = false;
    uint64_t samples = 0;
    napi_deferred deferred{};
    napi_async_work work{};
};
std::mutex jobsMutex;
std::unordered_map<std::string, std::shared_ptr<Job>> jobs;
struct Fd {
    int value = -1;
    ~Fd() { if (value >= 0) close(value); }
};
void Require(bool success, const char *code) { if (!success) throw std::runtime_error(code); }
void CheckCancelled(Job &job) { Require(!job.cancelled.load(), "CANCELLED"); }

void WritePcm(Job &job, int fd, const std::vector<int16_t> &pcm)
{
    CheckCancelled(job);
    Require(job.samples + pcm.size() <= kMaxSamples, "AUDIO_TOO_LONG");
    const auto *bytes = reinterpret_cast<const uint8_t *>(pcm.data());
    size_t remaining = pcm.size() * sizeof(int16_t);
    while (remaining) {
        const ssize_t count = write(fd, bytes, remaining);
        if (count < 0 && errno == EINTR) continue;
        Require(count > 0, "AUDIO_WRITE");
        remaining -= count;
        bytes += count;
    }
    job.samples += pcm.size();
}

std::vector<float> ReadMono(OH_AVBuffer *buffer, const OH_AVCodecBufferAttr &attr, int channels, int format)
{
    Require(channels >= 1 && channels <= 2, "AUDIO_FORMAT");
    const bool floating = format == SAMPLE_F32LE || format == SAMPLE_F32P;
    const bool planar = format == SAMPLE_F32P || format == SAMPLE_S16P;
    Require(floating || format == SAMPLE_S16LE || format == SAMPLE_S16P, "AUDIO_FORMAT");
    const int bytes = floating ? 4 : 2;
    Require(attr.offset >= 0 && attr.size >= 0 && attr.offset <= OH_AVBuffer_GetCapacity(buffer) - attr.size,
        "AUDIO_BUFFER");
    Require(attr.size % (bytes * channels) == 0, "AUDIO_BUFFER");
    const uint8_t *data = OH_AVBuffer_GetAddr(buffer);
    Require(data != nullptr || attr.size == 0, "AUDIO_BUFFER");
    const size_t frames = attr.size / (bytes * channels);
    std::vector<float> mono(frames);
    for (size_t frame = 0; frame < frames; ++frame) {
        float mixed = 0;
        for (int channel = 0; channel < channels; ++channel) {
            const size_t index = planar ? channel * frames + frame : frame * channels + channel;
            const uint8_t *sample = data + attr.offset + index * bytes;
            float value;
            if (floating) { std::memcpy(&value, sample, 4); }
            else { int16_t integer; std::memcpy(&integer, sample, 2); value = integer / 32768.0f; }
            Require(std::isfinite(value), "AUDIO_FORMAT");
            mixed += value / channels;
        }
        mono[frame] = mixed;
    }
    return mono;
}

void Decode(Job &job)
{
    CheckCancelled(job);
    Fd input{open(job.source.c_str(), O_RDONLY | O_CLOEXEC)};
    struct stat stat{};
    Require(input.value >= 0 && fstat(input.value, &stat) == 0 && S_ISREG(stat.st_mode) && stat.st_size > 0,
        "AUDIO_FILE");
    Require(stat.st_size <= 128LL * 1024 * 1024, "AUDIO_TOO_LONG");
    auto source = std::unique_ptr<OH_AVSource, decltype(&OH_AVSource_Destroy)>(
        OH_AVSource_CreateWithFD(input.value, 0, stat.st_size), OH_AVSource_Destroy);
    Require(source != nullptr, "AUDIO_FORMAT");
    auto sourceFormat = std::unique_ptr<OH_AVFormat, decltype(&OH_AVFormat_Destroy)>(
        OH_AVSource_GetSourceFormat(source.get()), OH_AVFormat_Destroy);
    int32_t tracks = 0;
    Require(sourceFormat && OH_AVFormat_GetIntValue(sourceFormat.get(), OH_MD_KEY_TRACK_COUNT, &tracks) &&
        tracks > 0 && tracks <= 32, "AUDIO_FORMAT");
    std::unique_ptr<OH_AVFormat, decltype(&OH_AVFormat_Destroy)> track(nullptr, OH_AVFormat_Destroy);
    uint32_t trackIndex = 0;
    for (int32_t i = 0; i < tracks; ++i) {
        track.reset(OH_AVSource_GetTrackFormat(source.get(), i));
        int32_t type = -1;
        if (track && OH_AVFormat_GetIntValue(track.get(), OH_MD_KEY_TRACK_TYPE, &type) && type == MEDIA_TYPE_AUD) {
            trackIndex = i; break;
        }
        track.reset();
    }
    Require(track != nullptr, "AUDIO_FORMAT");
    const char *mime = nullptr;
    int32_t rate = 0, channels = 0, sampleFormat = SAMPLE_S16LE;
    Require(OH_AVFormat_GetStringValue(track.get(), OH_MD_KEY_CODEC_MIME, &mime) && mime,
        "AUDIO_FORMAT");
    Require(OH_AVFormat_GetIntValue(track.get(), OH_MD_KEY_AUD_SAMPLE_RATE, &rate) &&
        OH_AVFormat_GetIntValue(track.get(), OH_MD_KEY_AUD_CHANNEL_COUNT, &channels), "AUDIO_FORMAT");
    auto demuxer = std::unique_ptr<OH_AVDemuxer, decltype(&OH_AVDemuxer_Destroy)>(
        OH_AVDemuxer_CreateWithSource(source.get()), OH_AVDemuxer_Destroy);
    Require(demuxer && OH_AVDemuxer_SelectTrackByID(demuxer.get(), trackIndex) == AV_ERR_OK, "AUDIO_FORMAT");
    auto codec = std::unique_ptr<OH_AVCodec, decltype(&OH_AudioCodec_Destroy)>(
        OH_AudioCodec_CreateByMime(mime, false), OH_AudioCodec_Destroy);
    Require(codec != nullptr, "AUDIO_FORMAT");
    Require(OH_AVFormat_SetIntValue(track.get(), OH_MD_KEY_ENABLE_SYNC_MODE, 1) &&
        OH_AVFormat_SetIntValue(track.get(), OH_MD_KEY_AUDIO_SAMPLE_FORMAT, SAMPLE_S16LE), "AUDIO_FORMAT");
    Require(OH_AudioCodec_Configure(codec.get(), track.get()) == AV_ERR_OK &&
        OH_AudioCodec_Prepare(codec.get()) == AV_ERR_OK && OH_AudioCodec_Start(codec.get()) == AV_ERR_OK,
        "AUDIO_DECODE");
    Fd output{open(job.destination.c_str(), O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600)};
    Require(output.value >= 0, "AUDIO_WRITE");
    job.outputCreated = true;
    std::unique_ptr<PcmResampler> resampler;
    bool inputEnd = false, outputEnd = false;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::minutes(2);
    while (!outputEnd) {
        CheckCancelled(job);
        Require(std::chrono::steady_clock::now() < deadline, "AUDIO_TIMEOUT");
        uint32_t index;
        if (!inputEnd) {
            const auto code = OH_AudioCodec_QueryInputBuffer(codec.get(), &index, 0);
            if (code == AV_ERR_OK) {
                auto *buffer = OH_AudioCodec_GetInputBuffer(codec.get(), index);
                Require(buffer && OH_AVDemuxer_ReadSampleBuffer(demuxer.get(), trackIndex, buffer) == AV_ERR_OK,
                    "AUDIO_DECODE");
                OH_AVCodecBufferAttr attr{};
                Require(OH_AVBuffer_GetBufferAttr(buffer, &attr) == AV_ERR_OK, "AUDIO_BUFFER");
                inputEnd = (attr.flags & AVCODEC_BUFFER_FLAGS_EOS) != 0;
                Require(OH_AudioCodec_PushInputBuffer(codec.get(), index) == AV_ERR_OK, "AUDIO_DECODE");
            } else Require(code == AV_ERR_TRY_AGAIN_LATER, "AUDIO_DECODE");
        }
        const auto code = OH_AudioCodec_QueryOutputBuffer(codec.get(), &index, 10000);
        if (code == AV_ERR_STREAM_CHANGED) {
            auto description = std::unique_ptr<OH_AVFormat, decltype(&OH_AVFormat_Destroy)>(
                OH_AudioCodec_GetOutputDescription(codec.get()), OH_AVFormat_Destroy);
            Require(description != nullptr && !resampler, "AUDIO_FORMAT");
            Require(OH_AVFormat_GetIntValue(description.get(), OH_MD_KEY_AUD_SAMPLE_RATE, &rate) &&
                OH_AVFormat_GetIntValue(description.get(), OH_MD_KEY_AUD_CHANNEL_COUNT, &channels) &&
                OH_AVFormat_GetIntValue(description.get(), OH_MD_KEY_AUDIO_SAMPLE_FORMAT, &sampleFormat), "AUDIO_FORMAT");
        } else if (code == AV_ERR_OK) {
            auto *buffer = OH_AudioCodec_GetOutputBuffer(codec.get(), index);
            OH_AVCodecBufferAttr attr{};
            Require(buffer && OH_AVBuffer_GetBufferAttr(buffer, &attr) == AV_ERR_OK, "AUDIO_BUFFER");
            if (!resampler) resampler = std::make_unique<PcmResampler>(rate);
            outputEnd = (attr.flags & AVCODEC_BUFFER_FLAGS_EOS) != 0;
            const auto mono = ReadMono(buffer, attr, channels, sampleFormat);
            WritePcm(job, output.value, resampler->Push(mono, outputEnd));
            Require(OH_AudioCodec_FreeOutputBuffer(codec.get(), index) == AV_ERR_OK, "AUDIO_DECODE");
        } else Require(code == AV_ERR_TRY_AGAIN_LATER, "AUDIO_DECODE");
    }
    Require(job.samples > 0, "AUDIO_EMPTY");
    Require(fsync(output.value) == 0, "AUDIO_WRITE");
    OH_AudioCodec_Stop(codec.get());
}

bool GetString(napi_env env, napi_value value, std::string &result, size_t limit)
{
    size_t size = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &size) != napi_ok || !size || size > limit) return false;
    std::vector<char> buffer(size + 1);
    if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &size) != napi_ok) return false;
    result.assign(buffer.data(), size);
    return result.find('\0') == std::string::npos;
}
void Execute(napi_env, void *data)
{
    auto &job = *static_cast<Job *>(data);
    try { Decode(job); } catch (const std::exception &error) { job.error = error.what(); }
    catch (...) { job.error = "AUDIO_DECODE"; }
}
void Complete(napi_env env, napi_status status, void *data)
{
    auto *raw = static_cast<Job *>(data);
    std::shared_ptr<Job> job;
    { std::lock_guard<std::mutex> lock(jobsMutex); job = jobs.at(raw->id); jobs.erase(raw->id); }
    if (job->cancelled || status != napi_ok) job->error = "CANCELLED";
    napi_value value;
    if (!job->error.empty()) {
        if (job->outputCreated) unlink(job->destination.c_str());
        napi_value code;
        napi_create_string_utf8(env, job->error.c_str(), NAPI_AUTO_LENGTH, &code);
        napi_create_error(env, code, code, &value);
        napi_reject_deferred(env, job->deferred, value);
    } else {
        napi_create_double(env, static_cast<double>(job->samples * 2), &value);
        napi_resolve_deferred(env, job->deferred, value);
    }
    napi_delete_async_work(env, job->work);
}
napi_value DecodePcm(napi_env env, napi_callback_info info)
{
    size_t count = 3;
    napi_value args[3], promise, name;
    napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    auto job = std::make_shared<Job>();
    if (count != 3 || !GetString(env, args[0], job->source, 4096) ||
        !GetString(env, args[1], job->destination, 4096) || !GetString(env, args[2], job->id, 128)) {
        napi_throw_error(env, "AUDIO_ARGUMENT", "Invalid decode arguments"); return nullptr;
    }
    { std::lock_guard<std::mutex> lock(jobsMutex);
        if (jobs.size() >= 2 || jobs.count(job->id)) { napi_throw_error(env, "AUDIO_BUSY", "Decoder busy"); return nullptr; }
        jobs.emplace(job->id, job);
    }
    napi_create_promise(env, &job->deferred, &promise);
    napi_create_string_utf8(env, "decodeAudioPcm", NAPI_AUTO_LENGTH, &name);
    if (napi_create_async_work(env, nullptr, name, Execute, Complete, job.get(), &job->work) != napi_ok ||
        napi_queue_async_work(env, job->work) != napi_ok) {
        { std::lock_guard<std::mutex> lock(jobsMutex); jobs.erase(job->id); }
        if (job->work) napi_delete_async_work(env, job->work);
        napi_value code, error;
        napi_create_string_utf8(env, "AUDIO_BUSY", NAPI_AUTO_LENGTH, &code);
        napi_create_error(env, code, code, &error);
        napi_reject_deferred(env, job->deferred, error);
    }
    return promise;
}
napi_value Cancel(napi_env env, napi_callback_info info)
{
    size_t count = 1; napi_value argument, result; std::string id;
    napi_get_cb_info(env, info, &count, &argument, nullptr, nullptr);
    if (count == 1 && GetString(env, argument, id, 128)) {
        std::lock_guard<std::mutex> lock(jobsMutex);
        auto it = jobs.find(id); if (it != jobs.end()) it->second->cancelled = true;
    }
    napi_get_undefined(env, &result); return result;
}
napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor properties[] = {
        {"decodeToPcm", nullptr, DecodePcm, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cancelDecode", nullptr, Cancel, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, 2, properties); return exports;
}
}
static napi_module module = {1, 0, nullptr, Init, "audiopcm", nullptr, {0}};
extern "C" __attribute__((constructor)) void RegisterAudioPcm() { napi_module_register(&module); }
