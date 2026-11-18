# PRODUCT REQUIREMENTS DOCUMENT (PRD)
## Project: Panda QQ - Live Karaoke DAW & Broadcast Suite
**Version:** 1.1.0-CROSS-PLATFORM  
**Status:** Approved for Development (Phase 1: Android Live • Phase 2: iOS, macOS, Windows)  
**Product Category:** Pro-Audio Multiplatform Workstation & Live Broadcast Utility  

---

## 1. Executive Summary & Objective

**Panda QQ** adalah aplikasi workstation audio digital (DAW) dan konsol siaran langsung karaoke berlatensi nol (*zero-latency*) yang dirancang khusus untuk kreator siaran langsung di TikTok Live, YouTube Live, dan Instagram.

Aplikasi ini menggabungkan pemutar karaoke YouTube dengan rak efek vokal sekelas studio rekaman profesional (Gate, De-Esser, 31-Band / Pro-Q Dynamic EQ, Kompresor, Reverb, Delay, Harmonizer, Chorus, dan True-Peak Limiter) yang didukung oleh **Core Audio DSP C++20 murni**.

---

## 2. Target Pengguna & Persona

1. **The Live Streamer / Singer (Pemula - Menengah)**:
   - Ingin bernyanyi karaoke dari YouTube dengan suara vokal tebal, halus, dan seimbang seperti rekaman album tanpa perlu mempelajari ilmu audio engineering rumit.
   - Mengandalkan tombol 1-sentuh (*1-Tap Presets* dan *Quick FX Stompboxes*).
2. **The Professional Musician / Soundman (Tingkat Lanjut)**:
   - Membutuhkan kontrol bedah mikro (*surgical audio control*): penyesuaian 31-Band Graphic EQ dengan gestur usap layar (*finger-draw*), dynamic sidechain carving, pengaturan milidetik delay, scale-lock harmonizer, dan penataan ulang rack insert secara modular.

---

## 3. Topografi Perangkat Keras: Paradigma 2 HP (Mobile) & Desktop Studio

### 3.1 Setup Mobile (Android & iOS)
```
[ 🎤 Mikrofon ] ──► [ Audio Interface / Soundcard OTG ] ◄──(Kabel USB OTG)──► [ 📱 HP 1: Panda QQ ]
                               │                                              (YouTube + Core DSP)
                               ├──► [ 📱 HP 2: TikTok Live App (Kamera & Chat) ]
                               └──► [ 🎧 In-Ear Monitor Kabel (0 ms Delay) ]
```
- **HP 1 (Panda QQ Host)**: Menjalankan pemutar YouTube, memproses DSP audio dua arah (*full-duplex*) via USB OTG.
- **HP 2 (TikTok Live Client)**: Membuka aplikasi TikTok resmi untuk kamera dan membaca komentar penonton. Menerima audio master digital stereo dari soundcard.
- **IEM Kabel**: Menyediakan monitoring vokal dan musik tanpa delay (*zero latency*).

### 3.2 Setup Desktop (macOS & Windows)
- Pada komputer PC/Mac, Panda QQ dapat berjalan berdampingan dengan software siaran (TikTok Live Studio / OBS Studio) dalam 1 perangkat laptop, dengan perutean audio internal digital (*Virtual Cable / Loopback*).

---

## 4. Arsitektur Multi-Platform & Strategi Driver OS

Proyek ini dibangun menggunakan pola **Monorepo**, di mana satu folder inti **`src/dsp/` (C++20)** dipakai bersama oleh seluruh platform untuk menjamin keseragaman karakter audio:

```
PandaQQ/
├── src/dsp/                 <-- CORE AUDIO C++20 (100% Shared Logic)
├── android/                 <-- Android (Kotlin + Jetpack Compose + Oboe NDK)
├── ios/                     <-- iOS / iPadOS (SwiftUI + CoreAudio / AUv3)
├── macos/                   <-- macOS (SwiftUI + CoreAudio Virtual HAL Bridge)
├── windows/                 <-- Windows (C++ WinUI 3 / Qt + WASAPI / ASIO)
└── docs/                    <-- Specs, PRD, & Panduan
```

### 4.1 Android
- **Driver HAL**: Google Oboe (AAudio dengan performa low-latency otomatis fallback ke OpenSL ES).
- **Koneksi Soundcard**: USB Audio Class 2.0 (UAC2) via kabel USB OTG.
- **Target Latensi**: $\le 12\text{ ms}$ round-trip.

### 4.2 iOS & iPadOS (iPhone / iPad)
- **Driver HAL**: Apple CoreAudio & `AVAudioEngine`.
- **Kebutuhan Driver Fisik**: **0% (Driverless / Class-Compliant)**. Semua soundcard USB langsung terdeteksi otomatis saat dicolokkan ke port USB-C atau Lightning Camera Adapter.
- **Target Latensi**: $3 - 5\text{ ms}$ (sangat cepat).
- **Fitur Ekstra**: **AUv3 Plugin Support**. Panda QQ dapat digunakan di dalam DAW iOS lain seperti GarageBand, Logic Pro for iPad, dan AUM.

### 4.3 macOS (MacBook & Mac Desktop)
- **Driver Hardware Soundcard**: **Driverless** via Apple CoreAudio UAC2.
- **Kebutuhan Driver Virtual (Internal Routing)**:
  - **PandaQQ Audio Bridge (CoreAudio HAL Plugin)**: Driver virtual internal ringan untuk menangkap (*capture*) audio YouTube dari browser Safari/Chrome langsung ke mixer Panda QQ tanpa kabel fisik tambahan.
- **Tata Letak GUI**: Tampilan desktop modular layar lebar (YouTube di kiri atas, spektrum RTA Pro-Q besar di tengah, fader console di kanan).

### 4.4 Windows (PC / Laptop)
Windows memiliki dua opsi mesin audio untuk fleksibilitas maksimal:
1. **Mode 1: WASAPI Exclusive Mode (Pilihan Pemula - Bebas Driver)**:
   - Bawaan native Windows 10/11. **Tidak butuh instalasi driver pihak ketiga**.
   - Latensi stabil di kisaran $8 - 12\text{ ms}$.
   - **Fitur WASAPI Loopback Capture**: Menggunakan flag `AUDCLNT_STREAMFLAGS_LOOPBACK` bawaan Windows untuk menangkap audio karaoke YouTube dari browser Chrome/Edge secara digital tanpa software kabel tambahan.
2. **Mode 2: ASIO Low-Latency Driver (Pilihan Profesional)**:
   - Mendukung driver ASIO resmi soundcard studio (*Focusrite ASIO*, *Yamaha Steinberg ASIO*) atau universal driver (*ASIO4ALL* / *FlexASIO*).
   - Latensi setara studio analog ($3 - 5\text{ ms}$).

---

## 5. Spesifikasi Detail Fitur Konsol Audio

### 5.1 Tata Letak Layar Mobile (Android & iPhone Portrait)
- **Layar Atas (38% Tinggi Layar)**:
  - Pemutar YouTube Karaoke (Rasio standar 16:9, ~220 dp).
  - Modal Pencarian Lagu Cepat (anti-geser saat keyboard virtual muncul).
  - Digital Key Transpose (`-3` s/d `+3` semitone).
  - Tombol `[🔒 LIVE LOCK]` (anti-senggol fader saat live).
  - Tombol `[💖 Donasi]` (modal pendukung DANA, GoPay, OVO `082116929992`).
- **Layar Tengah (12% Tinggi Layar)**:
  - **Baris Preset 1-Sentuh**: `[🎤 SAPA]`, `[✨ POP]`, `[🎸 AKUSTIK]`, `[💃 DANGDUT]`, `[🔥 RnB]`.
  - **Tombol Cepat Stompbox Send FX**:
    - `[✨ REVERB]`: On/Off ruang gema instan (Cyan glow).
    - `[🔁 DELAY]`: On/Off pantulan echo tempo-sync (Green glow).
    - `[👥 HARMONI]`: On/Off backing vocal otomatis nada terts atas (Purple glow - sangat pas untuk bagian *Reff/Chorus*).
    - `[🔊 SUB BASS]`: On/Off synthesizer sub-harmonic bass musik YouTube (Amber glow).
- **Layar Bawah (50% Tinggi Layar - Konsol 4 Fader)**:
  - Fader vertikal tebal untuk **`[VOKAL]`**, **`[EFEK]`**, **`[MUSIK]`**, dan **`[MASTER]`**.
  - **Integrated 24-Segment LED dBFS Meter**:
    - Hijau ($-\infty$ s/d $-12\text{ dBFS}$): Level aman.
    - Kuning ($-12$ s/d $-2\text{ dBFS}$): *Sweet spot* broadcast TikTok.
    - Merah ($-2$ s/d $0\text{ dBFS}$): Indikator bahaya clipping dengan **Peak-Hold 2,0 detik**.
  - Tombol **MUTE** (ketukan instan) dan tombol **SOLO** (dilindungi *Long-Press 0,8 detik* dengan mode CUE/PFL agar tidak mematikan siaran penonton).
  - **Drag-and-Drop Reordering**: Fader dapat dipindah urutan posisinya secara horizontal (ramah penyanyi bertangan kidal).
- **Drawer Studio Pro (Swipe Up)**:
  - Diusap dari bawah ke atas untuk membuka pengaturan bedah mikro: EQ 4-Band / 7-Band / 31-Band *Finger-Draw*, Pro-Q dynamic sidechain matrix, dan modul insert rack tambahan.

### 5.2 Rangkaian Insert Dinamis Vokal (Studio Insert Rack)
1. **High-Pass Filter**: Pemotongan sub-rumble di $85\text{ Hz}$ ($18\text{ dB/oct}$).
2. **Adaptive Noise Gate**: Menghilangkan dengung kipas angin/AC ruangan.
3. **Split-Band De-Esser (5.5 - 8.5 kHz)**: Menjinakkan desis tajam konsonan "S" dan "T".
4. **Pro-Q Style Dynamic Parametric EQ**: Pembentuk karakter vokal renyah (*air & body*).
5. **Studio Opto/VCA Compressor**: Meratakan nada tinggi dan bisikan dengan indikator *Gain Reduction (GR)* visual.
6. **Analog Warmth / Saturation**: Penebal vokal berkarakter tabung rekaman.
7. **Broadcast True-Peak Limiter**: Menahan sinyal maksimal di **$-1.0\text{ dBTP}$** agar transmisi audio AAC di TikTok tidak pernah pecah.

### 5.3 Modul Pengolah Musik YouTube (Music Conditioning Engine)
1. **Sub-Harmonic Synthesizer (MaxxBass style)**: Menghasilkan frekuensi harmonik rendah yang padat tanpa membuat speaker HP penonton jebol.
2. **Dynamic Vocal Pocket Carver**: Otomatis melubangi frekuensi musik di $1.5 - 3.5\text{ kHz}$ HANYA ketika vokal bernyanyi.
3. **Sidechain Auto-Ducker**: Menurunkan volume musik $2 - 3\text{ dB}$ secara lembut saat penyanyi menyapa penonton.

---

## 6. Persyaratan Non-Fungsional (Kinerja & Keamanan)

- **DSP Real-Time Safety**: Zero alokasi memori dinamis di audio render loop, bebas blocking mutex, SPSC ring buffer lock-free.
- **Beban CPU**: Di bawah $5\%$ dari 1 core CPU pada buffer 256 frame @ 48 kHz (Hasil benchmark aktual: **$1,24\%$**).
- **Keluaran True-Peak**: Mutlak tidak boleh melebihi $-1.0\text{ dBTP}$ dalam kondisi sinyal masukan ekstrem apa pun.
- **Tampilan Visual**: Stabil pada 60 FPS menggunakan GPU accelerated canvas.

---

## 7. Roadmap Rilis Fitur

| Versi | Target Platform | Fitur Utama |
|---|---|---|
| **v1.0.0 (Selesai)** | Android (APK) | Core C++20 DSP, Jetpack Compose UI, 4 Fader, Stompbox FX, YouTube split player, Donation modal. |
| **v1.2.0** | iOS (iPhone/iPad) | Porting ke SwiftUI + CoreAudio native driverless, optimasi iPad dual-pane, dukungan AUv3. |
| **v1.5.0** | macOS (MacBook) | Aplikasi desktop SwiftUI, CoreAudio Virtual Loopback HAL Driver untuk capture YouTube internal. |
| **v2.0.0** | Windows (PC) | Aplikasi desktop WinUI 3, WASAPI Exclusive + WASAPI Loopback Capture, ASIO Pro Driver Support. |
