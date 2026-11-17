#pragma once

#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

/**
 * @brief Studio Adaptive Noise Gate with envelope follower and hysteresis.
 */
class NoiseGate {
public:
    NoiseGate() {
        setParameters(-45.0f, 6.0f, 2.0f, 50.0f, 48000.0f);
        m_envelope = 0.0f;
        m_gain = 0.0f;
    }

    void setParameters(float thresholdDb, float hysteresisDb, float attackMs, float releaseMs, float sampleRate) noexcept {
        m_thresholdLinear = std::pow(10.0f, thresholdDb / 20.0f);
        m_closeThresholdLinear = std::pow(10.0f, (thresholdDb - hysteresisDb) / 20.0f);

        m_attackCoeff = std::exp(-1.0f / (attackMs * 0.001f * sampleRate));
        m_releaseCoeff = std::exp(-1.0f / (releaseMs * 0.001f * sampleRate));
        m_sampleRate = sampleRate;
    }

    void setEnabled(bool enabled) noexcept { m_enabled = enabled; }
    bool isEnabled() const noexcept { return m_enabled; }

    inline float processSample(float input) noexcept {
        if (!m_enabled) return input;

        const float absInput = std::abs(input);

        // Envelope detection
        if (absInput > m_envelope) {
            m_envelope = m_attackCoeff * m_envelope + (1.0f - m_attackCoeff) * absInput;
        } else {
            m_envelope = m_releaseCoeff * m_envelope + (1.0f - m_releaseCoeff) * absInput;
        }

        // Hysteresis logic
        if (m_isOpen) {
            if (m_envelope < m_closeThresholdLinear) {
                m_isOpen = false;
            }
        } else {
            if (m_envelope > m_thresholdLinear) {
                m_isOpen = true;
            }
        }

        const float targetGain = m_isOpen ? 1.0f : 0.0f;

        // Smooth gain transition
        if (targetGain > m_gain) {
            m_gain = m_attackCoeff * m_gain + (1.0f - m_attackCoeff) * targetGain;
        } else {
            m_gain = m_releaseCoeff * m_gain + (1.0f - m_releaseCoeff) * targetGain;
        }

        return input * m_gain;
    }

    void processBuffer(float* buffer, size_t numFrames) noexcept {
        if (!m_enabled) return;
        for (size_t i = 0; i < numFrames; ++i) {
            buffer[i] = processSample(buffer[i]);
        }
    }

    float getCurrentGain() const noexcept { return m_gain; }

private:
    bool m_enabled{true};
    bool m_isOpen{false};
    float m_thresholdLinear{0.0056f}; // ~ -45 dB
    float m_closeThresholdLinear{0.0028f}; // ~ -51 dB
    float m_attackCoeff{0.9f};
    float m_releaseCoeff{0.999f};
    float m_sampleRate{48000.0f};
    float m_envelope{0.0f};
    float m_gain{1.0f};
};

} // namespace OnLive::DSP
