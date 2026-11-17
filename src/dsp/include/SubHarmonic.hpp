#pragma once

#include "BiquadFilter.hpp"
#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

/**
 * @brief Psychoacoustic Sub-Harmonic Bass Generator (MaxxBass principle).
 * Generates perceived deep low-end warmth without blowing mobile phone speakers or overloading limiters.
 */
class SubHarmonic {
public:
    SubHarmonic() {
        setParameters(80.0f, 0.4f, 48000.0f);
        m_flipFlop = 1.0f;
        m_prevSample = 0.0f;
    }

    void setParameters(float crossoverFreqHz, float mix, float sampleRate) noexcept {
        m_crossoverFreq = crossoverFreqHz;
        m_mix = std::clamp(mix, 0.0f, 1.0f);
        m_sampleRate = sampleRate;

        m_lowPass.setParameters(FilterType::LowPass, crossoverFreqHz, 0.707f, 0.0f, sampleRate);
        m_postFilter.setParameters(FilterType::LowPass, crossoverFreqHz * 1.5f, 0.707f, 0.0f, sampleRate);
        m_highPassSafety.setParameters(FilterType::HighPass, 28.0f, 0.707f, 0.0f, sampleRate); // Sub-rumble cut
    }

    void setEnabled(bool enabled) noexcept { m_enabled = enabled; }
    bool isEnabled() const noexcept { return m_enabled; }
    void setIntensity(float intensity) noexcept { m_mix = std::clamp(intensity, 0.0f, 1.0f); }

    inline float processSample(float input) noexcept {
        if (!m_enabled || m_mix <= 0.001f) return input;

        // Extract low bass fundamental
        const float lowBass = m_lowPass.processSample(input);

        // Sub-harmonic frequency division via zero-crossing toggle
        if (m_prevSample <= 0.0f && lowBass > 0.0f) {
            m_flipFlop = -m_flipFlop;
        }
        m_prevSample = lowBass;

        // Generate synthetic octave down with saturation
        const float rawSub = lowBass * m_flipFlop;
        const float saturatedSub = std::tanh(rawSub * 1.5f);

        // Smooth synthetic sub and filter DC / sub rumble
        const float cleanSub = m_highPassSafety.processSample(m_postFilter.processSample(saturatedSub));

        // Blend with original input
        return input + cleanSub * m_mix;
    }

    void processBuffer(float* buffer, size_t numFrames) noexcept {
        if (!m_enabled || m_mix <= 0.001f) return;
        for (size_t i = 0; i < numFrames; ++i) {
            buffer[i] = processSample(buffer[i]);
        }
    }

private:
    bool m_enabled{true};
    float m_crossoverFreq{80.0f};
    float m_mix{0.4f};
    float m_sampleRate{48000.0f};

    BiquadFilter m_lowPass;
    BiquadFilter m_postFilter;
    BiquadFilter m_highPassSafety;

    float m_flipFlop{1.0f};
    float m_prevSample{0.0f};
};

} // namespace OnLive::DSP

