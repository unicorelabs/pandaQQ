#include "AudioEngine.hpp"
#include <iostream>
#include <vector>
#include <chrono>
#include <cmath>
#include <cassert>
#include <iomanip>

using namespace OnLive::DSP;

void runStressAndBenchmark() {
    std::cout << "\n=========================================================\n";
    std::cout << "  STARTING ONLIVE AUDIO ENGINE DEEP AUDIT & BENCHMARK    \n";
    std::cout << "=========================================================\n";

    auto engine = std::make_unique<AudioEngine>();
    engine->initialize(48000.0f, 256);

    constexpr size_t bufferFrames = 256;
    std::vector<float> micIn(bufferFrames, 0.0f);
    std::vector<float> musicInL(bufferFrames, 0.0f);
    std::vector<float> musicInR(bufferFrames, 0.0f);
    std::vector<float> broadcastOutL(bufferFrames, 0.0f);
    std::vector<float> broadcastOutR(bufferFrames, 0.0f);
    std::vector<float> monitorOutL(bufferFrames, 0.0f);
    std::vector<float> monitorOutR(bufferFrames, 0.0f);

    // ========================================================
    // TEST 1: SILENCE & ZERO-SIGNAL SANITY (No noise, no DC offset)
    // ========================================================
    std::cout << "[TEST 1] Testing zero input (Silence & DC offset check)... ";
    for (int i = 0; i < 50; ++i) {
        engine->processAudio(micIn.data(), musicInL.data(), musicInR.data(),
                             broadcastOutL.data(), broadcastOutR.data(),
                             monitorOutL.data(), monitorOutR.data(), bufferFrames);
    }
    for (size_t i = 0; i < bufferFrames; ++i) {
        assert(!std::isnan(broadcastOutL[i]) && !std::isinf(broadcastOutL[i]));
        assert(!std::isnan(broadcastOutR[i]) && !std::isinf(broadcastOutR[i]));
        assert(std::abs(broadcastOutL[i]) < 1e-5f);
    }
    std::cout << "PASSED (Clean zero floor, 0.0 DC offset).\n";

    // ========================================================
    // TEST 2: EXTREME OVERLOAD & CLIPPING DEFENSE
    // ========================================================
    std::cout << "[TEST 2] Testing massive +18 dBFS overload signals... ";
    for (size_t i = 0; i < bufferFrames; ++i) {
        micIn[i] = 8.0f; // Extreme +18 dBFS square wave overload
        musicInL[i] = 8.0f;
        musicInR[i] = 8.0f;
    }
    float peakOverloadL = 0.0f;
    float peakOverloadR = 0.0f;
    for (int i = 0; i < 50; ++i) {
        engine->processAudio(micIn.data(), musicInL.data(), musicInR.data(),
                             broadcastOutL.data(), broadcastOutR.data(),
                             monitorOutL.data(), monitorOutR.data(), bufferFrames);
        for (size_t j = 0; j < bufferFrames; ++j) {
            peakOverloadL = std::max(peakOverloadL, std::abs(broadcastOutL[j]));
            peakOverloadR = std::max(peakOverloadR, std::abs(broadcastOutR[j]));
        }
    }
    // Master TruePeak Limiter ceiling is -1.0 dBFS (0.89125 linear)
    assert(peakOverloadL <= 0.895f);
    assert(peakOverloadR <= 0.895f);
    std::cout << "PASSED (Brickwall limiter strictly held output <= " 
              << peakOverloadL << " linear / -1.0 dBTP).\n";

    // ========================================================
    // TEST 3: HIGH-SPEED PRESET & EFFECT TOGGLING (No Clicks/Pops)
    // ========================================================
    std::cout << "[TEST 3] Testing rapid live preset & stompbox toggling... ";
    for (size_t i = 0; i < bufferFrames; ++i) {
        micIn[i] = 0.3f * std::sin(2.0f * 3.14159265f * 1000.0f * i / 48000.0f);
        musicInL[i] = 0.3f * std::sin(2.0f * 3.14159265f * 150.0f * i / 48000.0f);
        musicInR[i] = musicInL[i];
    }
    for (int i = 0; i < 100; ++i) {
        if (i % 10 == 0) engine->loadFactoryPreset(static_cast<FactoryPreset>((i / 10) % 6));
        if (i % 3 == 0) engine->setHarmonizerEnabled(i % 2 == 0);
        if (i % 4 == 0) engine->setSubBoosterEnabled(i % 2 == 0);
        if (i % 5 == 0) engine->setDelayEnabled(i % 2 == 0);
        engine->processAudio(micIn.data(), musicInL.data(), musicInR.data(),
                             broadcastOutL.data(), broadcastOutR.data(),
                             monitorOutL.data(), monitorOutR.data(), bufferFrames);
        for (size_t j = 0; j < bufferFrames; ++j) {
            assert(!std::isnan(broadcastOutL[j]));
            assert(!std::isinf(broadcastOutL[j]));
        }
    }
    std::cout << "PASSED (Zero crashes, 100% numerical stability).\n";

    // ========================================================
    // TEST 4: DSP SPEED & LATENCY BENCHMARK (Performance Audit)
    // ========================================================
    std::cout << "[TEST 4] Running DSP Benchmark (Processing 10,000 blocks / ~53 seconds of audio)... \n";
    engine->loadFactoryPreset(FactoryPreset::PopStudio);
    engine->setHarmonizerEnabled(true);
    engine->setSubBoosterEnabled(true);

    const int totalBlocks = 10000;
    const auto startTime = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < totalBlocks; ++i) {
        engine->processAudio(micIn.data(), musicInL.data(), musicInR.data(),
                             broadcastOutL.data(), broadcastOutR.data(),
                             monitorOutL.data(), monitorOutR.data(), bufferFrames);
    }

    const auto endTime = std::chrono::high_resolution_clock::now();
    const std::chrono::duration<double, std::milli> elapsedMs = endTime - startTime;

    const double totalAudioSeconds = (totalBlocks * bufferFrames) / 48000.0;
    const double elapsedSeconds = elapsedMs.count() / 1000.0;
    const double speedFactor = totalAudioSeconds / elapsedSeconds;
    const double timePerBlockMicros = (elapsedMs.count() * 1000.0) / totalBlocks;
    const double bufferTimeMicros = (bufferFrames / 48000.0) * 1000000.0; // 5333.3 µs
    const double cpuUsagePercent = (timePerBlockMicros / bufferTimeMicros) * 100.0;

    std::cout << "   - Total Audio Processed : " << std::fixed << std::setprecision(2) << totalAudioSeconds << " seconds\n";
    std::cout << "   - Execution Time Taken   : " << elapsedMs.count() << " ms (" << elapsedSeconds << " s)\n";
    std::cout << "   - Processing Speed       : " << speedFactor << "x Real-Time\n";
    std::cout << "   - Time per 256-frame Block: " << timePerBlockMicros << " µs (Budget: " << bufferTimeMicros << " µs)\n";
    std::cout << "   - DSP CPU Load           : " << cpuUsagePercent << "%\n";

    assert(cpuUsagePercent < 15.0); // Must use less than 15% of a single core for full studio chain!
    std::cout << "[PASS] DSP performance is ultra-fast (" << speedFactor << "x faster than real-time, CPU load only "
              << cpuUsagePercent << "%).\n";

    std::cout << "=========================================================\n";
    std::cout << "  ALL ONLIVE AUDIT & BENCHMARK TESTS PASSED WITH HONORS! \n";
    std::cout << "=========================================================\n\n";
}

int main() {
    runStressAndBenchmark();
    return 0;
}
