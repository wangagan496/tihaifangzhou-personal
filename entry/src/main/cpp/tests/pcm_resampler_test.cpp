#include "pcm_resampler.h"
#include <cassert>
#include <iostream>

std::vector<float> Tone(int rate, double frequency)
{
    std::vector<float> signal(rate);
    for (int i = 0; i < rate; ++i) signal[i] = 0.5 * std::sin(6.283185307179586 * frequency * i / rate);
    return signal;
}
double Rms(const std::vector<int16_t> &signal)
{
    double sum = 0;
    for (size_t i = 100; i + 100 < signal.size(); ++i) sum += double(signal[i]) * signal[i];
    return std::sqrt(sum / (signal.size() - 200));
}
int main()
{
    for (int rate : {16000, 44100, 48000}) {
        const auto input = Tone(rate, 1000);
        PcmResampler whole(rate), fragmented(rate);
        const auto expected = whole.Push(input, true);
        std::vector<int16_t> actual;
        for (size_t i = 0; i < input.size(); i += 137) {
            const auto end = std::min(input.size(), i + 137);
            auto part = fragmented.Push(std::vector<float>(input.begin() + i, input.begin() + end), end == input.size());
            actual.insert(actual.end(), part.begin(), part.end());
        }
        assert(expected.size() == 16000 && actual == expected);
        assert(Rms(actual) > 10000 && Rms(actual) < 12000);
    }
    PcmResampler low(48000), high(48000), silence(48000), clipping(48000);
    assert(Rms(high.Push(Tone(48000, 12000), true)) < Rms(low.Push(Tone(48000, 1000), true)) * 0.02);
    for (auto sample : silence.Push(std::vector<float>(48000, 0), true)) assert(sample == 0);
    const auto limited = clipping.Push(std::vector<float>(48000, 2), true);
    assert(limited[1000] == 32767);
    bool rejected = false;
    try { PcmResampler invalid(0); } catch (...) { rejected = true; }
    assert(rejected);
    std::cout << "PASS: output rate, streaming phase, speech passband, anti-aliasing, silence, clipping, invalid rate\n";
}
