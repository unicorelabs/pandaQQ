#pragma once

#include "BiquadFilter.hpp"
#include <vector>
#include <algorithm>

namespace OnLive::DSP {

enum class DelayMode {
    MonoClean,
    StereoDual,
    PingPong
};

/**
 * @brief Studio Stereo Tap-Tempo Delay with Ping-Pong and Damping filters.
 */
class Delay {
    static constexpr size_t MAX_DELAY_SAMPLES = 96000; // 2.0 seconds @ 48kHz

public:
    Delay() {
        m_bufferL.fill(0.0f);
        m_bufferR.fill(0.0f);
        setParameters(DelayMode::PingPong, 300.0f, 0.45f, 0.7f, 3500.0f, 48000.0f);
    }

    void setParameters(DelayMode mode, float delayTimeMs, float feedback, [[maybe_unused]] float damping, float highCutHz, float sampleRate) noexcept {
        m_mode = mode;
        m_sampleRate = sampleRate;
        m_delaySamples = std::clamp(static_cast<size_t>(delayTimeMs * 0.001f * sampleRate), size_t(1), MAX_DELAY_SAMPLES - 1);
        m_feedback = std::clamp(feedback, 0.0f, 0.95f);

        m_filterL.setParameters(FilterType::LowPass, highCutHz, 0.707f, 0.0f, sampleRate);
        m_filterR.setParameters(FilterType::LowPass, highCutHz, 0.707f, 0.0f, sampleRate);
    }

    void setBpm(float bpm, float noteDivision = 0.5f) noexcept { // 0.5 = 1/8 note, 1.0 = 1/4 note
        if (bpm > 30.0f && bpm < 300.0f) {
            const float delayMs = (60000.0f / bpm) * noteDivision;
            m_delaySamples = std::clamp(static_cast<size_t>(delayMs * 0.001f * m_sampleRate), size_t(1), MAX_DELAY_SAMPLES - 1);
        }
    }

    void clearBuffers() noexcept {
        m_bufferL.fill(0.0f);
        m_bufferR.fill(0.0f);
        m_writeIdx = 0;
    }

    void processStereo(const float* input, float* outL, float* outR, size_t numFrames, float wetLevel) noexcept {
        for (size_t i = 0; i < numFrames; ++i) {
            const size_t readIdx = (m_writeIdx + MAX_DELAY_SAMPLES - m_delaySamples) % MAX_DELAY_SAMPLES;

            const float delayedL = m_bufferL[readIdx];
            const float delayedR = m_bufferR[readIdx];

            float nextL = input[i];
            float nextR = input[i];

            if (m_mode == DelayMode::PingPong) {
                // Cross-feedback ping-pong
                m_bufferL[m_writeIdx] = m_filterL.processSample(nextL + delayedR * m_feedback);
                m_bufferR[m_writeIdx] = m_filterR.processSample(nextR + delayedL * m_feedback);
            } else {
                m_bufferL[m_writeIdx] = m_filterL.processSample(nextL + delayedL * m_feedback);
                m_bufferR[m_writeIdx] = m_filterR.processSample(nextR + delayedR * m_feedback);
            }

            m_writeIdx = (m_writeIdx + 1) % MAX_DELAY_SAMPLES;

            outL[i] += delayedL * wetLevel;
            outR[i] += delayedR * wetLevel;
        }
    }

private:
    DelayMode m_mode{DelayMode::PingPong};
    float m_sampleRate{48000.0f};
    size_t m_delaySamples{14400}; // 300ms
    float m_feedback{0.45f};

    BiquadFilter m_filterL;
    BiquadFilter m_filterR;

    std::array<float, MAX_DELAY_SAMPLES> m_bufferL;
    std::array<float, MAX_DELAY_SAMPLES> m_bufferR;
    size_t m_writeIdx{0};
};

} // namespace OnLive::DSP
