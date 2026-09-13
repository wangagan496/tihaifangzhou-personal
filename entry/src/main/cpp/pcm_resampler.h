#ifndef THFZ_PCM_RESAMPLER_H
#define THFZ_PCM_RESAMPLER_H

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <deque>
#include <stdexcept>
#include <vector>

// Streaming, band-limited mono conversion. History and phase survive codec buffer boundaries.
class PcmResampler {
public:
    explicit PcmResampler(int rate) : rate_(rate)
    {
        if (rate < 8000 || rate > 96000) throw std::runtime_error("AUDIO_FORMAT");
        constexpr double pi = 3.14159265358979323846;
        const double cutoff = 0.45 * std::min(1.0, 16000.0 / rate);
        for (int p = 0; p < kPhases; ++p) {
            double sum = 0;
            for (int t = 0; t < kTaps; ++t) {
                const double x = t - kLeft - static_cast<double>(p) / kPhases;
                const double sinc = std::abs(x) < 1e-9 ? 2 * cutoff : std::sin(2 * pi * cutoff * x) / (pi * x);
                const double window = std::abs(x) >= 16 ? 0 : 0.5 * (1 + std::cos(pi * x / 16));
                coefficients_[p][t] = sinc * window;
                sum += coefficients_[p][t];
            }
            for (auto &c : coefficients_[p]) c /= sum;
        }
    }

    std::vector<int16_t> Push(const std::vector<float> &mono, bool final = false)
    {
        samples_.insert(samples_.end(), mono.begin(), mono.end());
        total_ += mono.size();
        std::vector<int16_t> output;
        while (outputCount_ * static_cast<uint64_t>(rate_) < total_ * 16000) {
            const uint64_t numerator = outputCount_ * rate_;
            const int64_t center = numerator / 16000;
            if (!final && center + 16 >= static_cast<int64_t>(total_)) break;
            const int phase = (numerator % 16000) * kPhases / 16000;
            double value = 0;
            for (int t = 0; t < kTaps; ++t) {
                const int64_t position = center + t - kLeft;
                if (position >= static_cast<int64_t>(base_) && position < static_cast<int64_t>(total_)) {
                    value += samples_[position - base_] * coefficients_[phase][t];
                }
            }
            output.push_back(static_cast<int16_t>(std::lround(std::clamp(value, -1.0, 32767.0 / 32768) * 32768)));
            ++outputCount_;
        }
        const int64_t keepFrom = static_cast<int64_t>(outputCount_ * rate_ / 16000) - kLeft;
        while (!samples_.empty() && static_cast<int64_t>(base_) < keepFrom) {
            samples_.pop_front();
            ++base_;
        }
        return output;
    }

private:
    static constexpr int kTaps = 32;
    static constexpr int kLeft = 15;
    static constexpr int kPhases = 256;
    int rate_;
    uint64_t base_ = 0;
    uint64_t total_ = 0;
    uint64_t outputCount_ = 0;
    std::deque<float> samples_;
    std::array<std::array<double, kTaps>, kPhases> coefficients_{};
};
#endif
