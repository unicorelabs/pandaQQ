#pragma once

#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

enum class FilterType {
    LowPass,
    HighPass,
    BandPass,
    Notch,
    Peaking,
    LowShelf,
    HighShelf
};

/**
 * @brief High-precision Transposed Direct Form II Biquad Filter.
 * Supports static and dynamic gain modulation (Pro-Q style).
 */
class BiquadFilter {
public:
    BiquadFilter() {
        reset();
        setParameters(FilterType::Peaking, 1000.0f, 0.707f, 0.0f, 48000.0f);
    }

    void reset() noexcept {
        m_s1 = 0.0f;
        m_s2 = 0.0f;
    }

    void setParameters(FilterType type, float frequencyHz, float q, float gainDb, float sampleRate) noexcept {
        m_type = type;
        m_frequency = std::clamp(frequencyHz, 20.0f, sampleRate * 0.49f);
        m_q = std::max(0.01f, q);
        m_gainDb = gainDb;
        m_sampleRate = sampleRate;

        updateCoefficients();
    }

    void setDynamicGainDb(float dynamicGainDb) noexcept {
        m_gainDb = dynamicGainDb;
        updateCoefficients();
    }

    float getGainDb() const noexcept { return m_gainDb; }
    float getFrequency() const noexcept { return m_frequency; }

    inline float processSample(float input) noexcept {
        // Transposed Direct Form II:
        // y[n] = b0*x[n] + s1[n-1]
        // s1[n] = b1*x[n] - a1*y[n] + s2[n-1]
        // s2[n] = b2*x[n] - a2*y[n]
        float output = m_b0 * input + m_s1;
        m_s1 = m_b1 * input - m_a1 * output + m_s2;
        m_s2 = m_b2 * input - m_a2 * output;

        // Anti-denormal flushing
        if (std::abs(m_s1) < 1e-15f) m_s1 = 0.0f;
        if (std::abs(m_s2) < 1e-15f) m_s2 = 0.0f;

        return output;
    }

    void processBuffer(float* buffer, size_t numFrames) noexcept {
        for (size_t i = 0; i < numFrames; ++i) {
            buffer[i] = processSample(buffer[i]);
        }
    }

private:
    void updateCoefficients() noexcept {
        constexpr float pi = 3.14159265358979323846f;
        const float w0 = 2.0f * pi * m_frequency / m_sampleRate;
        const float cosw0 = std::cos(w0);
        const float sinw0 = std::sin(w0);
        const float alpha = sinw0 / (2.0f * m_q);
        const float A = std::pow(10.0f, m_gainDb / 40.0f); // sqrt of linear gain for peaking/shelving

        float a0 = 1.0f;

        switch (m_type) {
            case FilterType::LowPass:
                m_b0 = (1.0f - cosw0) * 0.5f;
                m_b1 = 1.0f - cosw0;
                m_b2 = (1.0f - cosw0) * 0.5f;
                a0   = 1.0f + alpha;
                m_a1 = -2.0f * cosw0;
                m_a2 = 1.0f - alpha;
                break;

            case FilterType::HighPass:
                m_b0 = (1.0f + cosw0) * 0.5f;
                m_b1 = -(1.0f + cosw0);
                m_b2 = (1.0f + cosw0) * 0.5f;
                a0   = 1.0f + alpha;
                m_a1 = -2.0f * cosw0;
                m_a2 = 1.0f - alpha;
                break;

            case FilterType::Peaking:
                m_b0 = 1.0f + alpha * A;
                m_b1 = -2.0f * cosw0;
                m_b2 = 1.0f - alpha * A;
                a0   = 1.0f + alpha / A;
                m_a1 = -2.0f * cosw0;
                m_a2 = 1.0f - alpha / A;
                break;

            case FilterType::LowShelf: {
                const float sqrtA = std::sqrt(A);
                m_b0 = A * ((A + 1.0f) - (A - 1.0f) * cosw0 + 2.0f * sqrtA * alpha);
                m_b1 = 2.0f * A * ((A - 1.0f) - (A + 1.0f) * cosw0);
                m_b2 = A * ((A + 1.0f) - (A - 1.0f) * cosw0 - 2.0f * sqrtA * alpha);
                a0   = (A + 1.0f) + (A - 1.0f) * cosw0 + 2.0f * sqrtA * alpha;
                m_a1 = -2.0f * ((A - 1.0f) + (A + 1.0f) * cosw0);
                m_a2 = (A + 1.0f) + (A - 1.0f) * cosw0 - 2.0f * sqrtA * alpha;
                break;
            }

            case FilterType::HighShelf: {
                const float sqrtA = std::sqrt(A);
                m_b0 = A * ((A + 1.0f) + (A - 1.0f) * cosw0 + 2.0f * sqrtA * alpha);
                m_b1 = -2.0f * A * ((A - 1.0f) + (A + 1.0f) * cosw0);
                m_b2 = A * ((A + 1.0f) + (A - 1.0f) * cosw0 - 2.0f * sqrtA * alpha);
                a0   = (A + 1.0f) - (A - 1.0f) * cosw0 + 2.0f * sqrtA * alpha;
                m_a1 = 2.0f * ((A - 1.0f) - (A + 1.0f) * cosw0);
                m_a2 = (A + 1.0f) - (A - 1.0f) * cosw0 - 2.0f * sqrtA * alpha;
                break;
            }

            default:
                m_b0 = 1.0f; m_b1 = 0.0f; m_b2 = 0.0f;
                a0 = 1.0f; m_a1 = 0.0f; m_a2 = 0.0f;
                break;
        }

        // Normalize coefficients by 1/a0
        const float invA0 = 1.0f / a0;
        m_b0 *= invA0;
        m_b1 *= invA0;
        m_b2 *= invA0;
        m_a1 *= invA0;
        m_a2 *= invA0;
    }

    FilterType m_type{FilterType::Peaking};
    float m_frequency{1000.0f};
    float m_q{0.707f};
    float m_gainDb{0.0f};
    float m_sampleRate{48000.0f};

    // Filter Coefficients
    float m_b0{1.0f}, m_b1{0.0f}, m_b2{0.0f};
    float m_a1{0.0f}, m_a2{0.0f};

    // State history
    float m_s1{0.0f}, m_s2{0.0f};
};

} // namespace OnLive::DSP

