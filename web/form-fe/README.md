# 📋 FormUp Web Frontend (`form-fe`)

> **Modern, Fast, and Interactive Form & Quiz Builder Web Application**

Frontend aplikasi web **FormUp** dirancang untuk pembuatan, pengelolaan, dan pengisian formulir, kuis, ujian online, serta survei interaktif secara real-time. Dibangun dengan standar performa modern menggunakan **React 19**, **Vite**, **Tailwind CSS v4**, serta animasi interaktif **GSAP & Lenis**.

---

## 📑 Daftar Isi

1. [Fitur Utama](#-fitur-utama)
2. [Tech Stack](#-tech-stack)
3. [Prasyarat Sistem](#-prasyarat-sistem)
4. [Panduan Instalasi & Inisialisasi](#-panduan-instalasi--inisialisasi)
5. [Konfigurasi Environment (.env)](#-konfigurasi-environment-env)
6. [Daftar Perintah (Scripts)](#-daftar-perintah-scripts)
7. [Struktur Direktori](#-struktur-direktori)
8. [Routing & Halaman](#-routing--halaman)
9. [Integrasi API & Autentikasi](#-integrasi-api--autentikasi)
10. [Tipe Soal yang Didukung](#-tipe-soal-yang-didukung)
11. [Troubleshooting & FAQ](#-troubleshooting--faq)

---

## ✨ Fitur Utama

- 🎨 **Landing Page Interaktif (Awwwards Style)**: Desain sinematik modern dengan siluet smartphone 3D interaktif (*mouse tilt tracking*), *smooth inertial scrolling* (Lenis), dan *scroll-triggered animations* (GSAP).
- 📝 **Intelligent Form Builder**:
  - Drag-and-drop / susun urutan pertanyaan dengan mudah.
  - Dukungan teks kaya (*rich text*), rumus matematika LaTeX, dan *code snippet*.
  - Upload gambar & media pendukung per soal dengan fitur zoom.
  - Pengaturan batas waktu pengerjaan (*timer* & *auto-submit*).
  - Opsi pengacakan urutan soal (*shuffle questions*) dan opsi jawaban (*shuffle options*).
  - Batasan pengisian (hanya 1 kali per akun atau bebas).
- 🏆 **Kuis & Penilaian Poin Otomatis**:
  - Konfigurasi kunci jawaban dan bobot nilai per nomor.
  - Tampilan skor real-time dan pembahasan langsung bagi peserta.
- 📥 **Import Soal dari Word (.docx) & Excel (.xlsx / .csv)**:
  - Download template resmi.
  - Parse dokumen Word/Excel secara otomatis menjadi butir-butir soal.
- 📤 **Export Respons ke Excel & CSV**:
  - Unduh rekapan nilai dan jawaban seluruh responden dengan sanitasi karakter & format UTF-8 BOM.
- 📊 **Dashboard Analitik & Statistik Real-Time**:
  - Grafik distribusi skor, tingkat kelulusan, dan ringkasan persentase jawaban per nomor.
- 🔗 **Distribusi Instan & QR Code**:
  - Pembuatan tautan pendek kustom (*custom short link* `/f/{formLink}`).
  - Generator QR Code bawaan yang siap diunduh atau dipajang di proyektor.
- 🛡️ **Panel Kontrol & Moderasi Admin**:
  - Manajemen akun pengguna (Ban / Unban / Detail Pengguna / Hapus).
  - Manajemen formulir publik (Take Down / Restore / Detail / Hapus).
  - Moderasi laporan & umpan balik (*feedback*) dari pengguna.
- 🌓 **Tema Gelap & Terang (Dark / Light Mode)**:
  - Tampilan yang nyaman di mata dengan palet warna elegan (`#00897B` teal accent).

---

## 🛠 Tech Stack

| Kategori | Teknologi | Deskripsi |
|---|---|---|
| **Core Framework** | [React 19](https://react.dev/) | Library UI berbasis komponen reaktif terbaru |
| **Build Tool & Bundler** | [Vite 8](https://vitejs.dev/) | Tooling frontend ultra-cepat dengan Hot Module Replacement (HMR) |
| **Styling** | [Tailwind CSS v4](https://tailwindcss.com/) | Framework CSS utility-first generasi terbaru via `@tailwindcss/vite` |
| **Routing** | [React Router v7](https://reactrouter.com/) | Manajemen navigasi client-side dan route guard |
| **Icons** | [Lucide React](https://lucide.dev/) | Kumpulan ikon SVG modern dan ringan |
| **Animasi & Scroll** | [GSAP](https://gsap.com/) & [Lenis](https://lenis.darkroom.engineering/) | ScrollTrigger, 3D transform, dan smooth inertial scrolling |
| **Linting** | [ESLint 10](https://eslint.org/) | Standarisasi kualitas dan format kode |

---

## 📋 Prasyarat Sistem

Sebelum memulai, pastikan perangkat Anda telah terpasang:

1. **Node.js**: Versi LTS (`v18.x`, `v20.x`, atau lebih baru). Cek dengan `node -v`.
2. **npm**: Versi `9.x` atau lebih baru (bawaan Node.js). Cek dengan `npm -v`.
3. **Backend API FormUp**: Backend berbasis ASP.NET Core berjalan di `http://localhost:5000` (atau gunakan API staging/produksi).

---

## 🚀 Panduan Instalasi & Inisialisasi

Ikuti langkah-langkah berikut untuk menginisialisasi proyek dari awal:

### 1. Masuk ke Direktori Frontend
Dari direktori root repositori FormUp:
```bash
cd web/form-fe
```

### 2. Install Dependensi
Jalankan instalasi seluruh paket dependensi:
```bash
npm install
```

### 3. Buat File Konfigurasi Environment (`.env`)
Salin template environment atau buat file `.env` baru:
```bash
cp .env.example .env
```
Isi konfigurasi pada file `.env`:
```env
VITE_API_BASE_URL=http://localhost:5000
```
> *Catatan: Jika backend Anda berjalan di port lain (misal `https://localhost:7001` atau URL staging), sesuaikan nilai variabel di atas.*

### 4. Jalankan Development Server
```bash
npm run dev
```
Setelah server berjalan, buka browser di:
👉 **`http://localhost:5173`**

---

## ⚙️ Konfigurasi Environment (.env)

Aplikasi membaca variabel lingkungan dengan awalan `VITE_`:

| Variabel | Default (Fallback) | Keterangan |
|---|---|---|
| `VITE_API_BASE_URL` | `https://api.formup.my.id` | URL base endpoint API backend FormUp |

Contoh penggunaan untuk berbagai lingkungan:
```env
# Mode Development Lokal
VITE_API_BASE_URL=http://localhost:5000

# Mode Produksi / Staging
VITE_API_BASE_URL=https://api.formup.my.id
```

---

## 💻 Daftar Perintah (Scripts)

| Perintah | Deskripsi |
|---|---|
| `npm run dev` | Menjalankan local development server dengan Hot Module Replacement (HMR) |
| `npm run build` | Mengompilasi dan mengoptimasi aplikasi ke direktori `dist/` untuk rilis produksi |
| `npm run preview` | Menjalankan web server lokal untuk menguji hasil build produksi (`dist/`) |
| `npm run lint` | Menjalankan ESLint untuk mengecek kesalahan sintaks dan gaya penulisan kode |

---

## 📂 Struktur Direktori

```
web/form-fe/
├── public/                     # Aset statis publik
├── src/
│   ├── assets/                 # Gambar, ilustrasi, dan ikon internal
│   ├── components/             # Komponen modular reusable
│   │   ├── layout/             # Sidebar, Topbar, Header navigasi
│   │   └── ui/                 # ProtectedRoute, Button, Modal, Card, Input, dsb.
│   ├── features/               # Modul fitur berbasis domain aplikasi
│   │   ├── admin/              # Dashboard moderasi Admin (User, Form, Feedback)
│   │   ├── auth/               # Login, Register, Verifikasi OTP, Lupa Password
│   │   ├── dashboard/          # User Dashboard (My Forms, Templates, History, Respons)
│   │   ├── form-builder/       # Pembuat Form, Editor Pertanyaan, Import Dokumen
│   │   ├── form-responses/     # Tabel Respons Peserta & Grafik Analitik
│   │   ├── form-runner/        # Halaman Pengerjaan Form Publik & Hasil Nilai
│   │   ├── landing/            # Landing Page 3D Cinematic & Storytelling
│   │   └── profile/            # Pengaturan Profil & Ganti Password
│   ├── hooks/                  # Custom React Hooks (useDebounce, useTheme, dsb.)
│   ├── routes/                 # Konfigurasi rute tambahan (jika ada)
│   ├── services/
│   │   └── apiService.js       # Client REST API, fetch wrapper, dan manajemen token JWT
│   ├── utils/                  # Helper fungsi (format tanggal, sanitasi, parser LaTeX)
│   ├── App.jsx                 # Routing utama & Route Guard
│   ├── index.css               # Setup Tailwind CSS v4 & variabel warna global
│   └── main.jsx                # Entry point aplikasi React
├── .env.example                # Template variabel lingkungan
├── package.json                # Manifest dependensi & scripts
├── vite.config.js              # Konfigurasi Vite bundler
└── README.md                   # Dokumentasi teknis proyek
```

---

## 🗺️ Routing & Halaman

| Path URL | Komponen Halaman | Hak Akses | Deskripsi |
|---|---|---|---|
| `/` | `LandingPage` / redirect | Publik | Landing page jika belum login, atau auto-redirect ke `/dashboard` jika sudah login |
| `/login` | `Login` | Publik | Halaman masuk akun |
| `/register` | `Register` | Publik | Halaman pendaftaran akun baru |
| `/verify` | `VerifyRegister` | Publik | Halaman verifikasi kode OTP pendaftaran |
| `/forgot-password` | `ForgotPasswordPage` | Publik | Permintaan reset password via email |
| `/f/:formLink` | `FormRunnerPage` | Publik / Terproteksi | Halaman pengerjaan formulir / kuis oleh responden |
| `/f/:formLink/result/:responseId` | `FormResultPage` | Publik / Terproteksi | Tampilan skor hasil pengerjaan & pembahasan kuis |
| `/dashboard` | `UserHome` | Terotentikasi (User/Admin) | Beranda ringkasan statistik & aktivitas user |
| `/my-forms` | `MyForms` | Terotentikasi | Daftar seluruh formulir milik user & aksi bulk delete |
| `/templates` | `TemplateForm` | Terotentikasi | Galeri template formulir siap pakai |
| `/responses` | `ResponsesPage` | Terotentikasi | Riwayat formulir yang pernah diisi oleh user |
| `/history` | `UserHistory` | Terotentikasi | Log aktivitas dan riwayat formulir |
| `/create-form` | `CreateForm` | Terotentikasi | Pembuatan form baru / pemilihan modal awal |
| `/forms/:id/edit` | `FormBuilder` | Terotentikasi (Owner) | Editor lengkap butir soal, pengaturan skor, timer, media |
| `/forms/:id/responses` | `FormResponsesPage` | Terotentikasi (Owner) | Tabel daftar respon masuk & tombol export CSV/Excel |
| `/forms/:id/analytics` | `FormAnalyticsPage` | Terotentikasi (Owner) | Grafik visual analitik hasil pengumpulan data |
| `/admin` | `AdminDashboardPage` | Terotentikasi (**Role ADMIN**) | Panel kontrol user, take down form, & moderasi umpan balik |
| `/profile` | `ProfilePage` | Terotentikasi | Pengaturan akun, foto profil, dan kredensial |

---

## 🔐 Integrasi API & Autentikasi

1. **Penyimpanan Token**:
   - Token JWT disimpan di `localStorage` dan disinkronkan dengan `sessionStorage` serta cookie fallback (`formup_token`).
   - Setiap request ke endpoint terproteksi otomatis menyertakan header `Authorization: Bearer <token>`.
2. **Session Cleanup**:
   - Jika endpoint merespons kode `401 Unauthorized`, fungsi `clearSession()` otomatis membersihkan seluruh token dan mengarahkan pengguna kembali ke `/login`.
3. **Role-Based Access Control (RBAC)**:
   - Halaman `/admin` dilindungi oleh guard role (`user.role === 'ADMIN'`). Pengguna biasa yang mencoba mengakses akan dialihkan ke `/dashboard`.

---

## 📝 Tipe Soal yang Didukung

Aplikasi FormUp menggunakan ID referensi tipe pertanyaan yang konsisten antara frontend dan backend:

| Type ID | Tipe Pertanyaan | Deskripsi |
|:---:|---|---|
| **1** | **Essay / Teks Bebas** | Jawaban berupa teks isian singkat atau paragraf panjang |
| **2** | **Pilihan Ganda (Multiple Choice)** | Memilih satu jawaban dari beberapa opsi (dapat dinilai otomatis) |
| **3** | **Kotak Centang (Checkbox)** | Memilih satu atau beberapa jawaban yang sesuai |
| **4** | **Tanggal & Waktu (Date/Time)** | Pemilihan tanggal kalender atau waktu spesifik |
| **5** | **Benar / Salah (True/False)** | Pertanyaan biner validasi kebenaran pernyataan |

---

## 🐛 Troubleshooting & FAQ

### 1. Muncul pesan `Failed to fetch` atau respons lambat
- Pastikan backend API sudah berjalan (misal di port `5000`).
- Periksa file `.env` dan pastikan `VITE_API_BASE_URL` mengarah ke URL backend yang aktif.
- Pastikan konfigurasi CORS pada backend mengizinkan origin frontend (`http://localhost:5173`).

### 2. Setelah logout, halaman login langsung redirect kembali ke dashboard
- Sesi sebelumnya dibersihkan melalui fungsi `clearSession()`. Jika cookie masih tertinggal, bersihkan cache browser atau cookie pada domain `localhost`.

### 3. Tampilan styling tidak muncul atau rusak setelah update
- Proyek menggunakan **Tailwind CSS v4** dengan import `@import "tailwindcss";` di `src/index.css`.
- Jalankan `npm run build` untuk memastikan tidak ada kesalahan kompilasi style.

---

<div align="center">

**FormUp Web** — *Build Forms. Collect Answers. Analyze Results.*  
Made with ❤️ by FormUp Team

</div>
