<p align="center">
  <img src="Assets/FormUpLogoNameWide.png" alt="FormUp" width="420" />
</p>

# FormUp

![.NET](https://img.shields.io/badge/.NET-8.0-blue)
![Flutter](https://img.shields.io/badge/Flutter-3-02569B)
![React](https://img.shields.io/badge/React-19-61DAFB)
![License](https://img.shields.io/badge/License-Proprietary-lightgrey)

## Daftar Isi

1. [Pengenalan Project](#1-pengenalan-project)
2. [Overview & Fitur](#2-overview--fitur)
3. [Tech Stack, API, dan Sumber Daya Lain](#3-tech-stack-api-dan-sumber-daya-lain)
4. [Mulai Cepat: Setup & Cara Menjalankan](#4-mulai-cepat-setup--cara-menjalankan)
5. [Cara Kontribusi & Melaporkan Masalah](#5-cara-kontribusi--melaporkan-masalah)
6. [Penutup & Lisensi](#6-penutup--lisensi)

---

## 1. Pengenalan Project

**FormUp** adalah platform pembuat form modern — mirip Google Forms dan Quizizz — yang dapat digunakan untuk membuat survey, kuis, polling, ujian, dan assessment. Pengguna dapat merancang form dengan berbagai tipe soal, membagikannya melalui link atau QR code, mengumpulkan respons secara real-time, serta menganalisis hasilnya lengkap dengan skor otomatis.

FormUp dibangun sebagai **monorepo** yang terdiri dari tiga bagian:

| Bagian | Teknologi | Lokasi |
|--------|-----------|--------|
| **Backend API** | ASP.NET Core 8.0 (C#) + EF Core 8 + SQL Server | [`api/`](./api) |
| **Aplikasi Mobile** | Flutter 3 (Dart) | [`mobile/`](./mobile) |
| **Web Frontend** | React 19 + Vite + Tailwind CSS v4 | [`web/form-fe/`](./web/form-fe) |

---

## 2. Overview & Fitur

### Arsitektur Singkat

```
┌──────────────┐        ┌──────────────┐
│ Mobile       │        │ Web Frontend │
│ (Flutter)    │        │ (React+Vite) │
└──────┬───────┘        └──────┬───────┘
       │    http://localhost:5000/api   │
       └───────────┬───────────────────┘
                   ▼
          ┌─────────────────┐      ┌────────────┐
          │ FormUp API      │─────▶│ SQL Server │
          │ (ASP.NET Core)  │      └────────────┘
          │  - JWT auth     │      ┌────────────┐
          │  - OTP email    │─────▶│ SMTP       │
          │  - File upload  │      └────────────┘
          └─────────────────┘
```

### Fitur Utama

- **Form Builder** — berbagai tipe soal: essay, pilihan ganda, checkbox, tanggal & waktu, benar/salah, termasuk impor soal dari file `.docx` / `.pdf` / `.xlsx` / `.csv`
- **Publikasi & Bagikan** — link publik dengan custom short code, QR code, dan proteksi token
- **Pengisian Form** — timer dengan auto-submit, shuffle soal/jawaban, satu respons per orang, rate limiting
- **Analisis** — statistik respons, skor otomatis, dan export ke CSV/Excel/PDF
- **Autentikasi** — JWT dengan verifikasi OTP via email, refresh token, dan lupa password
- **Admin & Moderasi** — takedown/restore form, kelola user, kelola feedback pengguna

### Struktur Repository

```
FormUp/
├── api/                  # Backend ASP.NET Core 8
│   ├── Controllers/      # 11 controller (Auth, Forms, Questions, Responses, dst.)
│   ├── Models/           # Entitas EF Core + DbContext
│   ├── Services/         # JwtService, EmailService, dll.
│   ├── Migrations/       # Migrasi EF Core
│   ├── documentation/    # Dokumentasi API (Bahasa Indonesia)
│   └── wwwroot/uploads/  # Penyimpanan file upload
├── mobile/               # Aplikasi Flutter
│   ├── lib/features/     # auth, form, form_runner, home, responses, profile, dst.
│   ├── documentation/    # Dokumentasi konsumsi API dari mobile
│   └── ui_screen/        # Desain mockup layar (PNG/SVG)
├── web/
│   └── form-fe/          # Web frontend React 19 + Vite + Tailwind v4
└── graphify-out/         # Knowledge graph kodebase (hasil graphify)
```

---

## 3. Tech Stack, API, dan Sumber Daya Lain

### Teknologi Utama

| Lapisan | Teknologi | Keterangan |
|---------|-----------|------------|
| Backend | ASP.NET Core 8.0, EF Core 8, SQL Server | REST API, migrasi EF Core, soft delete, `ApiResponse<T>` |
| Mobile | Flutter 3 / Dart | `http`, `flutter_quill`, `mobile_scanner`, `audioplayers`, `share_plus` |
| Web | React 19, Vite 8, Tailwind CSS v4, react-router-dom v7, lucide-react, gsap | Pure JavaScript (`.jsx`), bukan TypeScript |
| Keamanan | JWT + refresh token, OTP email, PBKDF2 SHA256 (100.000 iterasi) | Rate limiting per grup endpoint |

### API Internal & Layanan Pendukung

- **FormUp API** (`http://localhost:5000/api`) — REST API utama; dokumentasi lengkap (Bahasa Indonesia) di [`api/documentation/`](./api/documentation/)
- **Swagger UI** (`http://localhost:5000/swagger`) — eksplorasi & uji endpoint dengan JWT auth (`persistAuthorization` aktif)
- **SMTP** (mis. Gmail App Password) — pengiriman email OTP untuk registrasi & reset password
- **SQL Server 2019+** — database utama (LocalDB/Express untuk development, Docker untuk macOS/Linux)

### Sumber Daya Lain

- **Dokumentasi API**: [`api/documentation/`](./api/documentation/) — endpoint, autentikasi, data model, status code, mekanisme keamanan, deployment
- **Dokumentasi Mobile**: [`mobile/documentation/`](./mobile/documentation/) — konsumsi API, autentikasi, penanganan error, alur form link
- **Panduan Backend**: [`api/README.md`](./api/README.md) — prasyarat per OS, deployment produksi, troubleshooting
- **Panduan Mobile**: [`mobile/README.md`](./mobile/README.md) — instalasi, konfigurasi `.env`, perintah berguna
- **Konvensi kodebase**: [`AGENTS.md`](./AGENTS.md)

---

## 4. Mulai Cepat: Setup & Cara Menjalankan

Jalankan ketiga bagian secara berurutan: backend dulu, lalu mobile dan/atau web.

### 4.1 Backend API

Prasyarat: [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0), `dotnet-ef` tool, dan SQL Server. Panduan instalasi lengkap per OS (Windows/macOS/Linux): [`api/README.md`](./api/README.md).

```bash
cd api
cp .env.example .env        # lalu isi DB_CONNECTION, JWT_KEY, SMTP_*
dotnet ef database update   # buat schema database
dotnet run                  # jalan di http://localhost:5000
```

Swagger UI tersedia di `http://localhost:5000/swagger`.

### 4.2 Aplikasi Mobile

Prasyarat: [Flutter SDK](https://docs.flutter.dev/get-started/install) (channel stable).

```bash
cd mobile
cp .env.example .env        # atur API_BASE_URL
flutter pub get
flutter run                 # pilih device yang tersedia
```

> **API_BASE_URL**: Android emulator pakai `http://10.0.2.2:5000/api` (10.0.2.2 = host machine); desktop/web/iOS simulator pakai `http://localhost:5000/api`; device fisik pakai IP LAN komputer.

Panduan lengkap: [`mobile/README.md`](./mobile/README.md).

### 4.3 Web Frontend

Prasyarat: [Node.js](https://nodejs.org) (rekomendasi versi LTS terbaru).

```bash
cd web/form-fe
npm install
npm run dev                 # jalan di http://localhost:5173
```

> Catatan: CORS di backend sudah mengizinkan `http://localhost:5173` dan `http://localhost:3000`.

### Perintah Berguna

| Bagian | Perintah |
|--------|----------|
| Backend | `dotnet build`, `dotnet ef migrations add <Nama>`, `dotnet publish -c Release` |
| Mobile | `flutter analyze`, `flutter test`, `flutter build apk`, `flutter clean` |
| Web | `npm run lint`, `npm run build`, `npm run preview` |

---

## 5. Cara Kontribusi & Melaporkan Masalah

### Kontribusi

1. Fork repository ini
2. Buat branch fitur (`git checkout -b feature/nama-fitur`)
3. Commit perubahan (`git commit -m 'Tambah fitur X'`)
4. Push ke branch (`git push origin feature/nama-fitur`)
5. Buka Pull Request

Standar kode yang diharapkan:

- **Backend**: gunakan async/await untuk operasi I/O, bungkus semua response dengan `ApiResponse<T>`, soft delete via kolom `deleted_at`, kolom database `snake_case`, jalankan `dotnet build` sebelum membuat PR
- **Mobile**: pastikan `flutter analyze` lulus sebelum PR
- **Web**: pastikan `npm run lint` lulus sebelum PR

### Melaporkan Masalah

Jika menemukan bug atau ingin mengusulkan fitur, silakan buka **Issue** baru di repository ini dengan menyertakan:

1. Judul yang jelas dan ringkas
2. Langkah untuk mereproduksi masalah (step-by-step)
3. Perilaku yang diharapkan vs perilaku yang terjadi
4. Bagian yang terdampak (api / mobile / web) beserta versi SDK/runtime
5. Screenshot atau log error (jika ada)

> Catatan: project ini belum memiliki unit test untuk backend — `dotnet test` akan gagal karena belum ada test project.

---

## 6. Penutup & Lisensi

FormUp dikembangkan sebagai platform pembuat form all-in-one yang mencakup backend, mobile, dan web dalam satu monorepo. Dokumentasi teknis yang lengkap (dalam Bahasa Indonesia) tersedia di folder `documentation/` pada masing-masing bagian.

**Lisensi**: project ini bersifat **proprietary and confidential**. Tidak diizinkan untuk mendistribusikan, menjual, atau menggunakan kode di luar lingkup yang telah disepakati tanpa izin tertulis dari pemilik.

---

Dibuat dengan 💙 oleh FormUp Team
