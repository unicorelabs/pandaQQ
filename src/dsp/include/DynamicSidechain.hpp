#pragma once

#include "BiquadFilter.hpp"
#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

/**
 * @brief Dynamic Vocal Pocket Carver (Pro-Q 3 Style External Dynamic Sidechain).
 * Automatically dips 1.5kHz - 3.5kHz in music ONLY when active vocal presence is detected.
 */
class DynamicSidechain {
public:
    DynamicSidechain() {
        setParameters(2000.0f, 1.2f, -5.0f, -28.0f, 48000.0f);
        m_vocalEnvelope = 0.0f;
    }

    void setParameters(float centerFreqHz, float q, float maxDuckingDb, float thresholdDb, float sampleRate) noexcept {
        m_centerFreq = centerFreqHz;
        m_q = q;
        m_maxDuckingDb = maxDuckingDb;
        m_thresholdLinear = std::pow(10.0f, thresholdDb / 20.0f);
        m_sampleRate = sampleRate;

        m_vocalDetectorFilter.setParameters(FilterType::BandPass, centerFreqHz, q, 0.0f, sampleRate);
        m_musicDynamicFilter.setParameters(FilterType::Peaking, centerFreqHz, q, 0.0f, sampleRate);

        m_attackCoeff = std::exp(-1.0f / (8.0f * 0.001f * sampleRate)); // 8ms fast attack
        m_releaseCoeff = std::exp(-1.0f / (120.0f * 0.001f * sampleRate)); // 120ms smooth musical release
    }

    void setEnabled(bool enabled) noexcept { m_enabled = enabled; }
    bool isEnabled() const noexcept { return m_enabled; }

    void processBuffer(float* musicBuffer, const float* vocalBuffer, size_t numFrames) noexcept {
        if (!m_enabled) return;

        for (size_t i = 0; i < numFrames; ++i) {
            // 1. Detect vocal energy in pocket zone
            const float vocalBand = m_vocalDetectorFilter.processSample(vocalBuffer[i]);
            const float vocalAbs = std::abs(vocalBand);

            if (vocalAbs > m_vocalEnvelope) {
                m_vocalEnvelope = m_attackCoeff * m_vocalEnvelope + (1.0f - m_attackCoeff) * vocalAbs;
            } else {
                m_vocalEnvelope = m_releaseCoeff * m_vocalEnvelope + (1.0f - m_releaseCoeff) * vocalAbs;
            }

            // 2. Calculate dynamic cut depth (dB)
            float dynamicGainDb = 0.0f;
            if (m_vocalEnvelope > m_thresholdLinear) {
                const float excessRatio = std::clamp((m_vocalEnvelope - m_thresholdLinear) / (m_thresholdLinear * 3.0f), 0.0f, 1.0f);
                dynamicGainDb = m_maxDuckingDb * excessRatio; // e.g. -4.5 dB
            }

            // 3. Modulate dynamic peaking filter on music
            m_musicDynamicFilter.setDynamicGainDb(dynamicGainDb);
            musicBuffer[i] = m_musicDynamicFilter.processSample(musicBuffer[i]);
        }
    }

    float getCurrentCutDb() const noexcept { return m_musicDynamicFilter.getGainDb(); }

private:
    bool m_enabled{true};
    float m_centerFreq{2000.0f};
    float m_q{1.2f};
    float m_maxDuckingDb{-5.0f};
    float m_thresholdLinear{0.039f}; // ~ -28 dB
    float m_attackCoeff{0.9f};
    float m_releaseCoeff{0.999f};
    float m_sampleRate{48000.0f};

    BiquadFilter m_vocalDetectorFilter;
    BiquadFilter m_musicDynamicFilter;
    float m_vocalEnvelope{0.0f};
};

} // namespace OnLive::DSP
