#pragma once

#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

/**
 * @brief Studio Vocal / Bus Compressor with Soft Knee and Sidechain detection.
 * Provides real-time Gain Reduction (GR in dB) for UI metering.
 */
class Compressor {
public:
    Compressor() {
        setParameters(-18.0f, 3.5f, 5.0f, 80.0f, 4.0f, 48000.0f);
        m_envelopeDb = -96.0f;
        m_gainReductionDb = 0.0f;
    }

    void setParameters(float thresholdDb, float ratio, float attackMs, float releaseMs, float kneeDb, float sampleRate) noexcept {
        m_thresholdDb = thresholdDb;
        m_ratio = std::max(1.0f, ratio);
        m_kneeDb = std::max(0.0f, kneeDb);
        m_attackCoeff = std::exp(-1.0f / (attackMs * 0.001f * sampleRate));
        m_releaseCoeff = std::exp(-1.0f / (releaseMs * 0.001f * sampleRate));
        m_sampleRate = sampleRate;
    }

    void setMakeupGainDb(float makeupDb) noexcept {
        m_makeupGainLinear = std::pow(10.0f, makeupDb / 20.0f);
    }

    void setEnabled(bool enabled) noexcept { m_enabled = enabled; }
    bool isEnabled() const noexcept { return m_enabled; }

    float getGainReductionDb() const noexcept { return m_gainReductionDb; }

    inline float processSample(float input, float sidechainInput = 0.0f, bool useSidechain = false) noexcept {
        if (!m_enabled) {
            m_gainReductionDb = 0.0f;
            return input;
        }

        const float detectorSignal = useSidechain ? sidechainInput : input;
        const float detectorAbs = std::abs(detectorSignal);
        const float detectorDb = (detectorAbs > 1e-6f) ? 20.0f * std::log10(detectorAbs) : -120.0f;

        // Envelope ballistics in dB domain
        if (detectorDb > m_envelopeDb) {
            m_envelopeDb = m_attackCoeff * m_envelopeDb + (1.0f - m_attackCoeff) * detectorDb;
        } else {
            m_envelopeDb = m_releaseCoeff * m_envelopeDb + (1.0f - m_releaseCoeff) * detectorDb;
        }

        // Soft-knee computation
        float targetGainDb = 0.0f;
        const float halfKnee = m_kneeDb * 0.5f;

        if (m_envelopeDb > m_thresholdDb + halfKnee) {
            // Above knee: full compression
            targetGainDb = (m_thresholdDb - m_envelopeDb) * (1.0f - 1.0f / m_ratio);
        } else if (m_envelopeDb > m_thresholdDb - halfKnee && m_kneeDb > 0.0f) {
            // Inside soft knee: quadratic interpolation
            const float diff = m_envelopeDb - m_thresholdDb + halfKnee;
            targetGainDb = -((1.0f - 1.0f / m_ratio) * (diff * diff)) / (2.0f * m_kneeDb);
        } else {
            // Below knee: no compression
            targetGainDb = 0.0f;
        }

        m_gainReductionDb = -targetGainDb; // positive value indicating dB cut
        const float gainLinear = std::pow(10.0f, targetGainDb / 20.0f);

        return input * gainLinear * m_makeupGainLinear;
    }

    void processBuffer(float* buffer, size_t numFrames) noexcept {
        if (!m_enabled) {
            m_gainReductionDb = 0.0f;
            return;
        }
        for (size_t i = 0; i < numFrames; ++i) {
            buffer[i] = processSample(buffer[i]);
        }
    }

    void processBufferSidechained(float* buffer, const float* sidechain, size_t numFrames) noexcept {
        if (!m_enabled) {
            m_gainReductionDb = 0.0f;
            return;
        }
        for (size_t i = 0; i < numFrames; ++i) {
            buffer[i] = processSample(buffer[i], sidechain[i], true);
        }
    }

private:
    bool m_enabled{true};
    float m_thresholdDb{-18.0f};
    float m_ratio{3.5f};
    float m_kneeDb{4.0f};
    float m_attackCoeff{0.9f};
    float m_releaseCoeff{0.999f};
    float m_sampleRate{48000.0f};
    float m_makeupGainLinear{1.2f};

    float m_envelopeDb{-96.0f};
    float m_gainReductionDb{0.0f};
};

} // namespace OnLive::DSP

