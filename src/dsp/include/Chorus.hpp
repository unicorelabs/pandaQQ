#pragma once

#include <array>
#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

/**
 * @brief Studio Multi-Tap Dimension Chorus with LFO modulation and stereo width spread.
 */
class Chorus {
    static constexpr size_t MAX_CHORUS_DELAY = 2048;

public:
    Chorus() {
        m_buffer.fill(0.0f);
        setParameters(1.0f, 0.5f, 1.0f, 48000.0f);
    }

    void setParameters(float rateHz, float depth, float stereoWidth, float sampleRate) noexcept {
        m_rate = rateHz;
        m_depth = std::clamp(depth, 0.0f, 1.0f);
        m_stereoWidth = std::clamp(stereoWidth, 0.0f, 2.0f);
        m_sampleRate = sampleRate;

        m_phaseInc = (2.0f * 3.14159265f * m_rate) / m_sampleRate;
        m_baseDelay = sampleRate * 0.015f; // 15ms base delay
        m_modDepthSamples = sampleRate * 0.005f * m_depth; // +/- 5ms modulation
    }

    void processStereo(const float* input, float* outL, float* outR, size_t numFrames, float wetLevel) noexcept {
        for (size_t i = 0; i < numFrames; ++i) {
            m_buffer[m_writeIndex] = input[i];

            // 90-degree quadrature LFO for wide stereo
            const float modL = std::sin(m_lfoPhase);
            const float modR = std::cos(m_lfoPhase);

            const float delaySamplesL = m_baseDelay + (modL * m_modDepthSamples);
            const float delaySamplesR = m_baseDelay + (modR * m_modDepthSamples * m_stereoWidth);

            // Linear interpolation
            const float sampleL = readInterpolated(delaySamplesL);
            const float sampleR = readInterpolated(delaySamplesR);

            m_lfoPhase += m_phaseInc;
            if (m_lfoPhase >= 2.0f * 3.14159265f) m_lfoPhase -= 2.0f * 3.14159265f;

            m_writeIndex = (m_writeIndex + 1) % MAX_CHORUS_DELAY;

            outL[i] += sampleL * wetLevel;
            outR[i] += sampleR * wetLevel;
        }
    }

private:
    float readInterpolated(float delaySamples) const noexcept {
        const float readPos = static_cast<float>(m_writeIndex + MAX_CHORUS_DELAY) - delaySamples;
        const size_t idx0 = static_cast<size_t>(readPos) % MAX_CHORUS_DELAY;
        const size_t idx1 = (idx0 + 1) % MAX_CHORUS_DELAY;
        const float frac = readPos - std::floor(readPos);

        return m_buffer[idx0] * (1.0f - frac) + m_buffer[idx1] * frac;
    }

    float m_rate{1.0f};
    float m_depth{0.5f};
    float m_stereoWidth{1.0f};
    float m_sampleRate{48000.0f};

    float m_phaseInc{0.00013f};
    float m_lfoPhase{0.0f};
    float m_baseDelay{720.0f};
    float m_modDepthSamples{120.0f};

    std::array<float, MAX_CHORUS_DELAY> m_buffer;
    size_t m_writeIndex{0};
};

} // namespace OnLive::DSP

