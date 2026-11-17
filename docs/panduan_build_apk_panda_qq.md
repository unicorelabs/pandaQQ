# PANDUAN LENGKAP: CARA MENGOMPILASI APK "PANDA QQ"
## Siap Langsung Diinstal di Smartphone Android

Aplikasi **Panda QQ (Live Karaoke DAW & Broadcast Suite)** telah dikonfigurasi lengkap dengan arsitektur C++20 NDK, Jetpack Compose UI, dan icon Panda ber-headphone.

Berikut adalah **3 cara praktis** untuk menghasilkan file `.apk` yang siap dikirim dan diinstal ke HP Anda:

---

### METODE 1: Menggunakan Android Studio (Sangat Mudah & Rekomendasi Resmi)

Ini adalah cara paling umum dan paling stabil bagi pemula maupun profesional:

1. **Unduh & Buka Android Studio**:
   - Jika belum ada, unduh gratis dari: [developer.android.com/studio](https://developer.android.com/studio).
2. **Buka Proyek**:
   - Pada layar selamat datang Android Studio, klik **Open**.
   - Arahkan dan pilih folder:
     ```
     /Users/a/Documents/OnLive/android
     ```
3. **Tunggu Sinkronisasi Otomatis (Gradle Sync)**:
   - Android Studio akan otomatis mengunduh SDK, NDK C++, dan pustaka yang dibutuhkan di latar belakang.
4. **Buat File APK**:
   - Pada bilah menu atas, klik:
     **`Build`** ➔ **`Build Bundle(s) / APK(s)`** ➔ **`Build APK(s)`**.
5. **Ambil File APK**:
   - Dalam 1–2 menit, akan muncul balon notifikasi di pojok kanan bawah:
     *"APK(s) generated successfully for 1 module: app"*
   - Klik tulisan **`locate`**, atau buka folder:
     ```
     /Users/a/Documents/OnLive/android/app/build/outputs/apk/debug/app-debug.apk
     ```
6. **Instal di HP Android**:
   - Kirim file `app-debug.apk` tersebut ke HP Android Anda (bisa lewat kabel data USB, WhatsApp Web, Google Drive, atau Telegram).
   - Di HP Android, ketuk file tersebut dan pilih **Install**. (Jika ada peringatan *"Install from unknown sources"*, izinkan sekali untuk menginstal).

---

### METODE 2: Otomatis di Cloud via GitHub Actions (Zero-Install di Laptop)

Jika Anda tidak ingin mengunduh software Android Studio sebesar 2–3 GB di laptop, Anda bisa memanfaatkan **GitHub Actions** yang sudah kami siapkan di file `.github/workflows/build_apk.yml`:

1. Buat repository baru di akun GitHub Anda (misal dinamai `PandaQQ`).
2. Jalankan perintah di Terminal:
   ```bash
   cd /Users/a/Documents/OnLive
   git remote add origin https://github.com/USERNAME-ANDA/PandaQQ.git
   git branch -M main
   git push -u origin main
   ```
3. Buka halaman GitHub Anda di browser, klik tab **Actions**.
4. Anda akan melihat proses build *"Build Panda QQ Android APK"* sedang berjalan di server cloud.
5. Begitu selesai (ikon centang hijau), klik workflow tersebut dan unduh file **`PandaQQ-Debug-APK`**.
6. Ekstrak zip-nya, Anda akan mendapatkan file `.apk` yang langsung bisa diinstal di HP!

---

### METODE 3: Menggunakan Baris Perintah Terminal (Bagi yang Memiliki Gradle & SDK)

Jika laptop Anda sudah terkonfigurasi dengan JDK 17 dan Android SDK Command-line Tools:
```bash
cd /Users/a/Documents/OnLive/android
./gradlew assembleDebug
```
File APK akan langsung tercipta di:
`android/app/build/outputs/apk/debug/app-debug.apk`

---

### Identitas Aplikasi Panda QQ yang Telah Terpasang:
- **Nama Aplikasi di HP**: `Panda QQ`
- **Application ID / Package**: `com.pandaqq.livekaraoke`
- **App Icon**: Panda lucu memakai headphone studio DJ dengan aksen neon cyan/amber (sudah dibuatkan di semua resolusi Android `mdpi` hingga `xxxhdpi`).
- **Versi**: `1.0.0`

