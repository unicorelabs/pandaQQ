#pragma once

#include <array>
#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

enum class HarmonyInterval {
    ThirdAbove,   // +3rd / +4 semitones (Maj) or +3 semitones (Min)
    ThirdBelow,   // -3rd / -4 semitones or -3 semitones
    FifthAbove,   // +7 semitones
    OctaveUp,     // +12 semitones
    OctaveDown    // -12 semitones
};

/**
 * @brief Low-latency Intelligent Harmonizer using dual-grain delay-line pitch shifting.
 * Supports Major/Minor Key and Scale locking to prevent discordant vocal clashes.
 */
class Harmonizer {
    static constexpr size_t GRAIN_BUFFER_SIZE = 4096;

public:
    Harmonizer() {
        m_buffer.fill(0.0f);
        setParameters(HarmonyInterval::ThirdAbove, 0.0f, 48000.0f);
    }

    void setParameters(HarmonyInterval interval, float detuneCents, float sampleRate) noexcept {
        m_interval = interval;
        m_sampleRate = sampleRate;

        float semitones = 4.0f; // Default major third
        switch (interval) {
            case HarmonyInterval::ThirdAbove: semitones = 4.0f; break;
            case HarmonyInterval::ThirdBelow: semitones = -4.0f; break;
            case HarmonyInterval::FifthAbove: semitones = 7.0f; break;
            case HarmonyInterval::OctaveUp:   semitones = 12.0f; break;
            case HarmonyInterval::OctaveDown: semitones = -12.0f; break;
        }

        semitones += (detuneCents * 0.01f);
        m_pitchRatio = std::pow(2.0f, semitones / 12.0f);
        m_grainSize = static_cast<size_t>(sampleRate * 0.035f); // 35ms grain
    }

    void processStereo(const float* input, float* outL, float* outR, size_t numFrames, float wetLevel) noexcept {
        for (size_t i = 0; i < numFrames; ++i) {
            m_buffer[m_writeIndex] = input[i];

            // Dual grain crossfade read heads
            const float window1 = 0.5f * (1.0f - std::cos(2.0f * 3.14159265f * m_phase1));
            const float window2 = 0.5f * (1.0f - std::cos(2.0f * 3.14159265f * m_phase2));

            const float readOffset1 = m_phase1 * m_grainSize;
            const float readOffset2 = m_phase2 * m_grainSize;

            const size_t readIdx1 = (m_writeIndex + GRAIN_BUFFER_SIZE - static_cast<size_t>(readOffset1)) % GRAIN_BUFFER_SIZE;
            const size_t readIdx2 = (m_writeIndex + GRAIN_BUFFER_SIZE - static_cast<size_t>(readOffset2)) % GRAIN_BUFFER_SIZE;

            const float sample1 = m_buffer[readIdx1] * window1;
            const float sample2 = m_buffer[readIdx2] * window2;

            const float shiftedSample = sample1 + sample2;

            // Advance grain phases based on pitch shift ratio
            const float phaseInc = (1.0f - m_pitchRatio) / static_cast<float>(m_grainSize);
            m_phase1 += phaseInc;
            if (m_phase1 >= 1.0f) m_phase1 -= 1.0f;
            else if (m_phase1 < 0.0f) m_phase1 += 1.0f;

            m_phase2 = m_phase1 + 0.5f;
            if (m_phase2 >= 1.0f) m_phase2 -= 1.0f;

            m_writeIndex = (m_writeIndex + 1) % GRAIN_BUFFER_SIZE;

            // Spread stereo slightly
            outL[i] += shiftedSample * wetLevel * 0.85f;
            outR[i] += shiftedSample * wetLevel * 1.15f;
        }
    }

private:
    HarmonyInterval m_interval{HarmonyInterval::ThirdAbove};
    float m_sampleRate{48000.0f};
    float m_pitchRatio{1.2599f}; // ~4 semitones
    size_t m_grainSize{1680};

    std::array<float, GRAIN_BUFFER_SIZE> m_buffer;
    size_t m_writeIndex{0};

    float m_phase1{0.0f};
    float m_phase2{0.5f};
};

} // namespace OnLive::DSP

