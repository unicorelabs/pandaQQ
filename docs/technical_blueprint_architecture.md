# TECHNICAL BLUEPRINT ARCHITECTURE
## Project: Live Karaoke Mobile DAW & Broadcast Engine
**Version:** 1.0.0-PRO  
**Target Platform:** Android (Initial Target) ➔ iOS ➔ macOS ➔ Windows  
**Engine Language:** Portable C++20 / Assembly NEON/AVX Optimizations  
**UI Framework:** Compose Multiplatform / Flutter (Declarative Native Render)

---

## 1. System Architecture Overview

The system is decoupled into three completely isolated layers to guarantee zero audio dropouts, cross-platform portability, and maximum UI responsiveness:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        LAYER 1: UI / UX LAYER                          │
│  - Declarative Components (Compose / Flutter)                          │
│  - 60 FPS Hardware-Accelerated OpenGL / Vulkan / Metal Surface         │
│  - Gesture Interpreters (Knobs, Faders, 31-Band Finger-Draw Canvas)    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (Non-blocking IPC / C-FFI / JNI)
                                    │ Atomic Variables & SPSC Ring Buffers
┌───────────────────────────────────▼────────────────────────────────────┐
│                    LAYER 2: C++20 CORE DSP ENGINE                      │
│  - Node Graph Matrix (Dual Input: Mic + YouTube/Media)                 │
│  - Dynamic Insert Rack (Gate, De-Esser, Pro-Q EQ, Comp, Limiter)       │
│  - Dynamic Sidechain & Vocal Pocket Carve Engine                       │
│  - 4-Bus Parallel FX Matrix (Reverb, Delay, Harmonizer, Chorus)        │
│  - True-Peak Master Limiter (-1.0 dBTP) & ITU-R BS.1770 LUFS Meter     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Direct Audio Callbacks
┌───────────────────────────────────▼────────────────────────────────────┐
│              LAYER 3: PLATFORM AUDIO DRIVER HAL (C++ WRAPPER)          │
│   [Android: Google Oboe]       [iOS/macOS: CoreAudio AUv3]  [Win: WASAPI]│
│   AAudio (Performance Mode)    RemoteIO / AudioOutputUnit   Exclusive Mode
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Real-Time Audio Engine & Memory Architecture

### 2.1 The Zero-Allocation Real-Time Thread Contract
The audio callback executes on an OS real-time high-priority thread. Under no circumstances may this thread block or pause:
1. **No Memory Allocation**: Zero calls to `malloc`, `free`, `new`, `delete`, or dynamically resizing containers (`std::vector::push_back`). All buffer arrays and delay lines are pre-allocated during engine initialization.
2. **Lock-Free Concurrency**: Standard mutexes (`std::mutex`, `pthread_mutex`) are strictly prohibited in the audio path.
3. **No File/Network/Log I/O**: No file writes, prints, or debugging calls on the audio render thread.

### 2.2 UI ⟷ Audio Thread Communication (SPSC Lock-Free FIFO)
- **Control Parameters (Knobs, Faders, Toggles)**: Sent from UI to Audio Thread via a Single-Producer Single-Consumer (SPSC) circular lock-free ring buffer or lock-free atomic parameter array (`std::atomic<float>`).
- **Metering & Visual Spectrum (Meters, RTA Curves, GR)**: Extracted by the Audio Thread via atomic peak values written into an SPSC Ring Buffer, polled by the UI at 60 Hz.

```cpp
// Example: Lock-Free Atomic Parameter Representation
struct alignas(64) ChannelParameters {
    std::atomic<float> faderGain{1.0f};        // Linear Gain
    std::atomic<float> panPosition{0.0f};      // -1.0 (Left) to +1.0 (Right)
    std::atomic<bool>  isMuted{false};
    std::atomic<bool>  isSolo{false};
    std::atomic<float> sendLevels[4];          // Reverb, Delay, Harm, Chorus
    std::atomic<float> peakMeterValue{0.0f};   // Read by UI
    std::atomic<float> gainReductionDb{0.0f};  // Comp feedback to UI
};
```

---

## 3. Signal Flow & Processing Graph

```
[ PHYSICAL MIC IN ] (Soundcard USB OTG)
         │
         ▼
[ VOCAL INSERT RACK ]
   ├─► 1. Brickwall Sub-Cut (Butterworth 24dB/oct @ 90Hz)
   ├─► 2. Adaptive Noise Gate (Lookahead 1.5ms, Hysteresis 6dB)
   ├─► 3. Split-Band De-Esser (5.5kHz - 8.5kHz dynamic notch)
   ├─► 4. Pro-Q Style Dynamic EQ (4-Band / 7-Band / 31-Band / Multi-Node)
   ├─► 5. Dual-Opto Vocal Compressor (Soft Knee, Auto Makeup Gain)
   ├─► 6. Analog Tube/Tape Saturation (Odd/Even harmonic blend)
   └─► 7. Vocal Brickwall Peak Limiter (Ceiling -0.5 dBFS)
         │
         ├─────────────────► [SIDECHAIN DETECTOR] ───────────────┐
         │                                                       │
         ├─► Send 1: Reverb Bus (Algorithmic Damped Plate/Hall)   │
         ├─► Send 2: Delay Bus (Ping-Pong / Tap-Tempo BPM Sync)  │
         ├─► Send 3: Intelligent Harmonizer (PSOLA Pitch Track)  │
         ├─► Send 4: Dimension Chorus (Multi-tap modulated)      │
         │                                                       │
         ▼ (Dry Vocal Stereo Panned)                             │
         │                                                       │
[ YOUTUBE MUSIC IN ]                                             │
         │                                                       │
         ▼                                                       │
[ MUSIC PROCESSING ENGINE ]                                      │
   ├─► 1. Sub-Harmonic Generator (Psychoacoustic Bass Synthesis) │
   ├─► 2. Dynamic Vocal Pocket Carver (Band-cut @ 1.5-3kHz) <────┤ (Ducks mids
   ├─► 3. Sidechain Master Ducker (Wideband compressor) <────────┘  on vocal)
   ├─► 4. Stereo Width Control (M/S Processing)
   └─► 5. LUFS Leveler & Normalizer (Target: -14 LUFS)
         │
         ▼ (Music Stereo Panned)
         │
         ▼
   [ SUMMING BUS ] (Vocal Dry + FX Returns + Music)
         │
         ▼
   [ MASTER FINALIZER ]
   ├─► Master Glue Compressor (Bus VCA style, Ratio 2:1)
   ├─► Master 31-Band Output EQ (Room Acoustic correction)
   ├─► True-Peak Brickwall Limiter (Ceiling -1.0 dBTP)
   └─► EBU R128 Loudness & True-Peak Measurement
         │
         ├──────────────────────────────┐
         ▼                              ▼
  [ BROADCAST OUTPUT ]           [ MONITOR CUE OUTPUT ]
(USB OTG to HP 2 TikTok)       (3.5mm Headphone / IEM)
```

---

## 4. Hardware Abstraction Layer (HAL) Driver Strategy

### 4.1 Android Implementation (Google Oboe)
- **Audio API**: AAudio (Android 8.1+) with automatic fallback to OpenSL ES.
- **Sharing Mode**: `AAUDIO_SHARING_MODE_EXCLUSIVE` when connected via USB Audio Interface to achieve minimum latency.
- **Performance Mode**: `AAUDIO_PERFORMANCE_MODE_LOW_LATENCY`.
- **Target Round-Trip Latency**: $\le 12 \text{ ms}$ on Snapdragon 7/8 series chipsets.
- **Buffer Size**: Double buffer callback (e.g. 96 or 128 frames per burst @ 48kHz).

### 4.2 iOS / macOS Implementation (CoreAudio)
- **AudioUnit v3**: RemoteIO / VoiceProcessingIO unit.
- **Sample Rate**: Native 48.0 kHz.
- **I/O Buffer Duration**: 0.0029s (128 frames) to achieve $\approx 3-5 \text{ ms}$ round-trip latency.

### 4.3 Windows Implementation
- **Driver Model**: WASAPI Exclusive Mode with push/event-driven buffer; Optional ASIO driver support for professional soundcards.

---

## 5. DSP Module Mathematical Specifications

1. **Biquad Filters (EQ)**: Transposed Direct Form II implementation for optimal numerical precision and lowest phase distortion at 32-bit floating point.
2. **Sub-Harmonic Synthesizer**: Low-pass extraction of 40-90Hz band, followed by full-wave rectification and 1/2 octave frequency divider, mixed back with high-pass filtered fundamental.
3. **True Peak Detection**: $4\times$ oversampling FIR polyphase filter to intercept inter-sample peaks before D/A conversion or AAC streaming encoder ingestion on TikTok.
