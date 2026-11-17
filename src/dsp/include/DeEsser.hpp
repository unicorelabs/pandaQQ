#pragma once

#include "BiquadFilter.hpp"
#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

/**
 * @brief Split-Band Vocal De-Esser.
 * Detects harsh high-frequency energy (5.5kHz - 8.5kHz) and dynamically ducks only the sibilance.
 */
class DeEsser {
public:
    DeEsser() {
        setParameters(6500.0f, -22.0f, 4.0f, 48000.0f);
        m_envelope = 0.0f;
    }

    void setParameters(float frequencyHz, float thresholdDb, float ratio, float sampleRate) noexcept {
        m_bandFilter.setParameters(FilterType::BandPass, frequencyHz, 1.2f, 0.0f, sampleRate);
        m_thresholdLinear = std::pow(10.0f, thresholdDb / 20.0f);
        m_ratio = std::max(1.0f, ratio);
        m_attackCoeff = std::exp(-1.0f / (1.0f * 0.001f * sampleRate)); // Fast 1ms attack
        m_releaseCoeff = std::exp(-1.0f / (40.0f * 0.001f * sampleRate)); // 40ms release
    }

    void setEnabled(bool enabled) noexcept { m_enabled = enabled; }
    bool isEnabled() const noexcept { return m_enabled; }

    inline float processSample(float input) noexcept {
        if (!m_enabled) return input;

        // Isolate sibilance band
        const float bandSignal = m_bandFilter.processSample(input);
        const float bandAbs = std::abs(bandSignal);

        if (bandAbs > m_envelope) {
            m_envelope = m_attackCoeff * m_envelope + (1.0f - m_attackCoeff) * bandAbs;
        } else {
            m_envelope = m_releaseCoeff * m_envelope + (1.0f - m_releaseCoeff) * bandAbs;
        }

        float sibilanceAttenuation = 1.0f;
        if (m_envelope > m_thresholdLinear) {
            const float excess = m_envelope / m_thresholdLinear;
            sibilanceAttenuation = std::pow(excess, -(1.0f - 1.0f / m_ratio));
        }

        // Subtract excessive sibilance from input
        return input - bandSignal * (1.0f - sibilanceAttenuation);
    }

    void processBuffer(float* buffer, size_t numFrames) noexcept {
        if (!m_enabled) return;
        for (size_t i = 0; i < numFrames; ++i) {
            buffer[i] = processSample(buffer[i]);
        }
    }

private:
    bool m_enabled{true};
    BiquadFilter m_bandFilter;
    float m_thresholdLinear{0.079f}; // ~ -22 dB
    float m_ratio{4.0f};
    float m_attackCoeff{0.9f};
    float m_releaseCoeff{0.999f};
    float m_envelope{0.0f};
};

} // namespace OnLive::DSP
