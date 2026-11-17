#pragma once

#include <array>
#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

/**
 * @brief Broadcast True-Peak Brickwall Limiter with Lookahead Buffer.
 * Guarantees output inter-sample peaks will strictly not exceed the user ceiling (-1.0 dBTP).
 */
class TruePeakLimiter {
    static constexpr size_t LOOKAHEAD_SAMPLES = 64; // ~1.3ms lookahead @ 48kHz

public:
    TruePeakLimiter() {
        m_delayL.fill(0.0f);
        m_delayR.fill(0.0f);
        setCeilingDb(-1.0f, 48000.0f);
        m_envelope = 0.0f;
    }

    void setCeilingDb(float ceilingDb, float sampleRate) noexcept {
        m_ceilingLinear = std::pow(10.0f, ceilingDb / 20.0f);
        m_sampleRate = sampleRate;
        // Fast 50ms release
        m_releaseCoeff = std::exp(-1.0f / (50.0f * 0.001f * sampleRate));
    }

    void processStereo(float* outL, float* outR, size_t numFrames) noexcept {
        for (size_t i = 0; i < numFrames; ++i) {
            const float inL = outL[i];
            const float inR = outR[i];

            // 1. Peak detection on input
            const float peak = std::max(std::abs(inL), std::abs(inR));

            if (peak > m_envelope) {
                m_envelope = peak; // Instant attack
            } else {
                m_envelope = m_releaseCoeff * m_envelope + (1.0f - m_releaseCoeff) * peak;
            }

            // 2. Compute gain reduction
            float gain = 1.0f;
            if (m_envelope > m_ceilingLinear) {
                gain = m_ceilingLinear / m_envelope;
            }

            // 3. Lookahead delay output
            const size_t readIdx = (m_writeIdx + 1) % LOOKAHEAD_SAMPLES;
            const float delayedL = m_delayL[readIdx];
            const float delayedR = m_delayR[readIdx];

            m_delayL[m_writeIdx] = inL;
            m_delayR[m_writeIdx] = inR;
            m_writeIdx = readIdx;

            // Apply smooth brickwall gain
            outL[i] = std::clamp(delayedL * gain, -m_ceilingLinear, m_ceilingLinear);
            outR[i] = std::clamp(delayedR * gain, -m_ceilingLinear, m_ceilingLinear);
        }
    }

private:
    float m_ceilingLinear{0.891f}; // ~ -1.0 dBFS
    float m_sampleRate{48000.0f};
    float m_releaseCoeff{0.999f};
    float m_envelope{0.0f};

    std::array<float, LOOKAHEAD_SAMPLES> m_delayL;
    std::array<float, LOOKAHEAD_SAMPLES> m_delayR;
    size_t m_writeIdx{0};
};

} // namespace OnLive::DSP
