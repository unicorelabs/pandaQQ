# AGENT HARD-RULES & UI/UX DESIGN SYSTEM SPECIFICATION
## Project: Live Karaoke Mobile DAW & Broadcast Suite
**Scope:** Mandatory Guidelines for AI Agents and Software Engineers  

---

# PART 1: AUDIO DSP & ENGINEERING HARD-RULES

Every engineer or AI agent writing code for this project **MUST STRICTLY OBEY** these rules without exception. Violating any rule will cause audio clicks, buffer under-runs, or system crashes during live broadcasts.

### Rule 1.1: Zero Dynamic Allocation on the Audio Thread
- **STRICT PROHIBITION**: Never invoke `new`, `delete`, `malloc`, `free`, `calloc`, `realloc`, or use standard containers that allocate dynamically (`std::vector::push_back`, `std::string`, `std::map`) inside any audio callback or DSP processing method.
- **MANDATORY PATTERN**: All audio buffers, impulse response arrays, and delay-line buffers must be pre-allocated at initialization or when the audio sample rate changes.

### Rule 1.2: No Blocking Locks or Mutexes in Audio Callbacks
- **STRICT PROHIBITION**: Do not use `std::mutex`, `std::unique_lock`, `pthread_mutex`, or condition variables on the real-time audio thread. Priority inversion will cause fatal buffer dropouts.
- **MANDATORY PATTERN**: All cross-thread communication (UI to Audio Thread, or Audio Thread to UI) must use **Lock-Free Single-Producer Single-Consumer (SPSC) Ring Buffers** or atomic primitives (`std::atomic<float>`, `std::atomic<bool>`).

### Rule 1.3: No I/O Operations on Audio Thread
- **STRICT PROHIBITION**: Do not read/write files, execute network calls, format strings, or output console logs (`printf`, `std::cout`, `__android_log_print`) inside the audio processing loop.

### Rule 1.4: Strict Denormal Number Prevention
- Floating-point calculations that underflow to subnormal/denormal numbers drastically slow down CPU execution on mobile ARM processors.
- **MANDATORY PATTERN**: The engine must set the hardware FTZ (Flush-To-Zero) and DAZ (Denormals-Are-Zero) flags in the audio thread floating-point control register (e.g. `_mm_setcsr` or ARM `fpscr`).

### Rule 1.5: Deterministic Sample-Rate and Buffer Agility
- The DSP engine must seamlessly handle buffer sizes from 64 to 1024 frames and sample rates of 44.1 kHz, 48.0 kHz, and 96.0 kHz without pitch distortion. Polyphase sinc or high-grade cubic interpolation resamplers must be used where necessary.

---

# PART 2: UI/UX DESIGN SYSTEM SPECIFICATIONS

The UI theme is styled after **High-End Professional Broadcast & Mastering Hardware** (a blend of SSL, Neve, TC Electronic, and FabFilter aesthetic): dark, high contrast, clean typography, tactile skeuomorphic-modern controls, and ultra-readable indicators under bright stage lighting.

```
┌──────────────────────────────────────────────────────────────┐
│ PALET WARNA PRO STUDIO (DARK THEME)                          │
├──────────────────────────────────────────────────────────────┤
│ Background Deep Surface: #121316 (Matte Charcoal Black)      │
│ Channel Strip Chassis:   #1A1C22 (Brushed Aluminum Dark)     │
│ Panel Borders & Dividers:#2A2D35 (Subtle 1px Contrast)       │
│ Accent Primary (Vocal):  #00D2FF (Cyan Electric)             │
│ Accent Music (YouTube):  #FF9900 (Warm Amber Gold)           │
│ Accent FX (Reverb/Delay):#9D00FF (Studio Purple / Magenta)   │
│ Text Primary:            #FFFFFF (Pure White, 100%)          │
│ Text Secondary / Labels: #8E94A0 (Neutral Gray, 70%)         │
└──────────────────────────────────────────────────────────────┘
```

---

## 2.1 Rotary Knobs (Tombol Putar) Guidelines
1. **Interaction Model**:
   - **Vertical Drag Gesture**: Moving finger up increases value; moving finger down decreases value. (Do not use circular dragging; circular dragging is awkward on mobile screens).
   - **Double-Tap to Reset**: Double-tapping resets the knob to its factory default value (e.g. `0.0 dB` or center `12:00`).
2. **Visual Feedback & Readability**:
   - **Outer Arc Ring (Glow Meter)**: Displays the current value as an active illuminated arc around the knob perimeter (Cyan for Vocal, Amber for Music, Purple for FX).
   - **Value Callout Tag**: Directly beneath the knob, an explicit numerical value with unit must always be displayed (e.g. `2.4 kHz`, `-18.5 dB`, `45 ms`). Never show an uncalibrated knob without numerical units.
3. **Touch Target Size**:
   - Minimum bounding touch area must be at least **$48 \times 48 \text{ dp}$** even if the visual knob graphic is smaller, preventing missed finger taps.

---

## 2.2 Vertical Faders & Channel Strips Guidelines
1. **4 Main Front-Screen Faders**:
   - Di layar depan Live Mode, tersedia **4 Fader Strip** berdampingan: `[VOKAL]`, `[EFEK]`, `[MUSIK]`, dan `[MASTER]`.
   - Lebar per strip: $\approx 85 - 95 \text{ dp}$ (sangat proporsional di lebar layar Android $360 - 412 \text{ dp}$).
   - **Fader Master**: Memiliki warna fader cap khusus (Metallic Silver dengan garis indikator Merah Terang) untuk membedakannya secara visual dari channel audio biasa.
2. **Drag-and-Drop Channel Reordering**:
   - Pengguna dapat menahan (*long-press 0.5s*) pada label nama channel strip.
   - Perangkat memberikan **Haptic Vibration Feedback**, strip sedikit membesar (*scale 1.05x*), lalu pengguna bebas menggeser urutan channel ke kiri atau ke kanan (contoh: memindahkan Master ke paling kiri bagi pengguna kidal).
   - Urutan posisi fader otomatis disimpan ke `SharedPreferences` / Local Storage.
3. **Tenth-of-a-dB Fine Tuning & Unity Gain**:
   - Long-press pada thumb fader memicu "Fine Resolution Mode" ($0.1 \text{ dB}$ steps).
   - Double-tap pada fader otomatis mengembalikan nilai ke `0.0 dB (Unity Gain)`.

---

## 2.3 Ready-to-Use Factory Presets (Cold Boot Rule)
- **Zero-Setup Guarantee**: Saat aplikasi pertama kali di-install dan dibuka (*cold boot*), aplikasi **TIDAK BOLEH** berada dalam kondisi kosong (*flat/dry*).
- **Default Active Preset**: Otomatis memuat preset **`[✨ POP STUDIO]`**:
  - Gate aktif (-45 dB) memotong noise ruangan.
  - Compressor aktif dengan auto-makeup gain halus.
  - Reverb Hall & Echo tipis sudah aktif dan seimbang.
  - Auto-Carve pada musik YouTube aktif.
- Pengguna pemula hanya perlu mencolokkan mic, memutar lagu, dan langsung bernyanyi dengan hasil suara profesional tanpa perlu menyentuh pengaturan apa pun.

---

## 2.3 Integrated 24-Segment LED dB Meters (Beside Faders)
1. **Placement**:
   - The LED light strip must sit **directly parallel and adjacent to the right side of the fader path**.
2. **Color Scale & Thresholds**:
   - **Segments 1 - 14 (Green)**: $-\infty \text{ dBFS}$ to $-12 \text{ dBFS}$ (Normal Safe Operating Level).
   - **Segments 15 - 20 (Yellow/Amber)**: $-12 \text{ dBFS}$ to $-2 \text{ dBFS}$ (Nominal Broadcast Sweet Spot).
   - **Segments 21 - 24 (Bright Red)**: $-2 \text{ dBFS}$ to $0 \text{ dBFS}$ and above (Immediate Overload Danger).
3. **Peak-Hold Bar**:
   - A distinct single floating LED segment stays illuminated at the highest peak for **2.0 seconds** before decaying, alerting the singer to clipping events even after high notes end.
4. **Hardware Acceleration**:
   - Rendered using canvas shaders (Vulkan/Metal/OpenGL) to guarantee 60 FPS without taxing the CPU.

---

## 2.4 Panning Controls (Pan Pot) Guidelines
1. **Visual Style**:
   - Horizontal slider bar or rotary dial with an **indented Center Detent (C)** notch.
2. **Snapping Behavior**:
   - Magnetic snap to center: When dragged within $\pm 5\%$ of center, it magnetically locks to `C (Center)`.
3. **Numeric Display**:
   - Must clearly read `L 100%` ... `L 15%` ... `CENTER` ... `R 15%` ... `R 100%`.

---

## 2.5 Channel Buttons: MUTE & SOLO
1. **MUTE Button**:
   - Physical look: Square studio-console button with beveled edges.
   - **Instant Single Tap**.
   - Muted State: Illuminates in **Bright Flashing/Pulsing Red** (`#FF1744`), making it impossible to overlook.
2. **SOLO Button (Safety Guard)**:
   - **Long-Press Activation Required (0.8 seconds hold)**.
   - A circular progress ring fills during the 0.8s hold to indicate activation intent.
   - Active State: Illuminates in **Solid Glowing Amber Gold** (`#FFD700`).
   - Default Audio Routing: **CUE / PFL Mode** (isolates channel only in performer's headphones; live stream audience continues to hear the full mix).

---

## 2.6 Live Ergonomics: "Live Lock Mode"
- Prominent Padlock Icon in the top header bar: **`[🔒 LIVE LOCK]`**.
- When locked:
  - Faders, panning, and effect knobs are frozen against accidental touch.
  - Video play/pause, song search, and 1-tap presets remain operational.
  - Prevents accidental disruptions during live performances.
