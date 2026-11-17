#pragma once

#include "BiquadFilter.hpp"
#include <array>
#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

/**
 * @brief Studio Algorithmic Damped Stereo Reverb (Comb & All-Pass lattice).
 * Features Pre-Delay, Damping, Low-Cut, and High-Cut filters for pristine vocal clarity.
 */
class Reverb {
    static constexpr size_t NUM_COMBS = 8;
    static constexpr size_t NUM_ALLPASS = 4;
    static constexpr size_t MAX_PREDELAY = 9600; // 200ms @ 48kHz
    static constexpr size_t MAX_COMB_BUF = 4096;
    static constexpr size_t MAX_AP_BUF = 2048;

public:
    Reverb() {
        setParameters(2.5f, 35.0f, 0.4f, 120.0f, 6500.0f, 48000.0f);
        clearBuffers();
    }

    void setParameters(float decayTimeSec, float preDelayMs, float damping, float lowCutHz, float highCutHz, float sampleRate) noexcept {
        m_sampleRate = sampleRate;
        m_decayTime = std::clamp(decayTimeSec, 0.2f, 10.0f);
        m_preDelayFrames = std::min(static_cast<size_t>(preDelayMs * 0.001f * sampleRate), MAX_PREDELAY - 1);
        m_damping = std::clamp(damping, 0.0f, 0.95f);

        m_lowCut.setParameters(FilterType::HighPass, lowCutHz, 0.707f, 0.0f, sampleRate);
        m_highCut.setParameters(FilterType::LowPass, highCutHz, 0.707f, 0.0f, sampleRate);

        // Feedback calculation based on T60 decay time
        m_feedback = std::clamp(std::exp(-3.0f / (m_decayTime * 15.0f)), 0.5f, 0.96f);
    }

    void clearBuffers() noexcept {
        m_preDelayBuffer.fill(0.0f);
        m_preDelayIndex = 0;
        for (auto& buf : m_combBuffers) buf.fill(0.0f);
        for (auto& idx : m_combIndices) idx = 0;
        for (auto& flt : m_combFilterStore) flt = 0.0f;
        for (auto& buf : m_allPassBuffers) buf.fill(0.0f);
        for (auto& idx : m_allPassIndices) idx = 0;
    }

    void processStereo(const float* input, float* outL, float* outR, size_t numFrames, float wetLevel) noexcept {
        static constexpr size_t combLengths[NUM_COMBS] = { 1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617 };
        static constexpr size_t allPassLengths[NUM_ALLPASS] = { 556, 441, 341, 225 };

        for (size_t i = 0; i < numFrames; ++i) {
            // 1. Pre-Delay line
            m_preDelayBuffer[m_preDelayIndex] = input[i];
            const size_t readIdx = (m_preDelayIndex + MAX_PREDELAY - m_preDelayFrames) % MAX_PREDELAY;
            const float preDelayed = m_preDelayBuffer[readIdx];
            m_preDelayIndex = (m_preDelayIndex + 1) % MAX_PREDELAY;

            // 2. Pre-filtering (Clean clarity)
            const float filteredInput = m_highCut.processSample(m_lowCut.processSample(preDelayed));

            // 3. Parallel Comb Filters
            float combSumL = 0.0f;
            float combSumR = 0.0f;

            for (size_t c = 0; c < NUM_COMBS; ++c) {
                const size_t len = combLengths[c];
                size_t& idx = m_combIndices[c];
                float output = m_combBuffers[c][idx];

                // One-pole lowpass damping
                m_combFilterStore[c] = (output * (1.0f - m_damping)) + (m_combFilterStore[c] * m_damping);
                m_combBuffers[c][idx] = filteredInput + (m_combFilterStore[c] * m_feedback);

                idx = (idx + 1) % len;

                if (c % 2 == 0) combSumL += output;
                else combSumR += output;
            }

            // 4. Series All-Pass Diffusers
            for (size_t a = 0; a < NUM_ALLPASS; ++a) {
                const size_t len = allPassLengths[a];
                size_t& idx = m_allPassIndices[a];

                const float bufOutL = m_allPassBuffers[a][idx];
                const float newInL = combSumL + (bufOutL * 0.5f);
                m_allPassBuffers[a][idx] = newInL;
                combSumL = -newInL * 0.5f + bufOutL;

                idx = (idx + 1) % len;
            }

            outL[i] += combSumL * 0.08f * wetLevel;
            outR[i] += combSumR * 0.08f * wetLevel;
        }
    }

private:
    float m_sampleRate{48000.0f};
    float m_decayTime{2.5f};
    size_t m_preDelayFrames{1680};
    float m_damping{0.4f};
    float m_feedback{0.84f};

    BiquadFilter m_lowCut;
    BiquadFilter m_highCut;

    std::array<float, MAX_PREDELAY> m_preDelayBuffer;
    size_t m_preDelayIndex{0};

    std::array<std::array<float, MAX_COMB_BUF>, NUM_COMBS> m_combBuffers;
    std::array<size_t, NUM_COMBS> m_combIndices;
    std::array<float, NUM_COMBS> m_combFilterStore;

    std::array<std::array<float, MAX_AP_BUF>, NUM_ALLPASS> m_allPassBuffers;
    std::array<size_t, NUM_ALLPASS> m_allPassIndices;
};

} // namespace OnLive::DSP
