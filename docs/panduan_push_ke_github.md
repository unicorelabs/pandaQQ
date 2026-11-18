# PANDUAN MENGHUBUNGKAN PROYEK KE GITHUB

Dokumen ini memandu Anda menghubungkan proyek Panda QQ di komputer lokal ke akun GitHub Anda agar proses kompilasi APK otomatis (Cloud Build) dapat langsung berjalan.

---

### Langkah 1: Buat Repository Baru di Akun GitHub Anda

1. Buka browser dan masuk ke akun GitHub Anda di: [github.com/new](https://github.com/new).
2. Masukkan nama repository: `PandaQQ` (atau nama lain sesuai keinginan Anda).
3. Pilih opsi visibilitas: **Public** atau **Private**.
4. **PENTING**: Kosongkan centang *"Add a README file"*, *"Add .gitignore"*, dan *"Choose a license"* karena file-file tersebut sudah lengkap di komputer kita.
5. Klik tombol hijau **Create repository**.

---

### Langkah 2: Hubungkan dan Unggah Proyek dari Terminal

Buka Terminal di komputer Anda, lalu jalankan perintah berikut:

```bash
cd /Users/a/Documents/OnLive

# Tambahkan URL repository GitHub Anda (ganti USERNAME dengan username GitHub Anda)
git remote add origin https://github.com/USERNAME/PandaQQ.git

# Pastikan branch utama bernama main
git branch -M main

# Unggah semua kode ke GitHub
git push -u origin main
```

---

### Langkah 3: Mengambil File APK dari GitHub Actions

1. Buka repository Anda di browser GitHub.
2. Klik tab **Actions** di bilah atas.
3. Anda akan melihat workflow bernama **"Panda QQ CI/CD & Automated APK Build"** sedang berjalan.
4. Tunggu sekitar 2-3 menit hingga proses selesai (muncul ikon centang hijau).
5. Klik nama workflow tersebut, lalu gulir ke bawah ke bagian **Artifacts**.
6. Klik **`PandaQQ-Debug-APK`** untuk mengunduh file APK yang siap langsung diinstal di smartphone Android Anda!

---

### Langkah 4: Membuat Rilis Resmi (Opsional)

Jika Anda ingin membuat halaman download publik agar siapa pun bisa mengunduh file `.apk` langsung:

```bash
cd /Users/a/Documents/OnLive

# Buat tag versi baru
git tag v1.0.0

# Unggah tag ke GitHub
git push origin v1.0.0
```

GitHub Actions akan secara otomatis menerbitkan halaman **Releases** dan melampirkan file APK siap pasang.

