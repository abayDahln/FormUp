# FormUp

Platform pembuat form modern — mirip Google Forms dan Quizizz — untuk survey, kuis, polling, ujian, dan assessment. FormUp terdiri dari tiga bagian dalam satu monorepo:

| Bagian | Teknologi | Lokasi |
|--------|-----------|--------|
| **Backend API** | ASP.NET Core 8.0 (C#) + EF Core 8 + SQL Server | [`api/`](./api) |
| **Aplikasi Mobile** | Flutter 3 (Dart) | [`mobile/`](./mobile) |
| **Web Frontend** | React 19 + Vite + Tailwind CSS v4 | [`web/form-fe/`](./web/form-fe) |

## Fitur Utama

- **Form Builder** — berbagai tipe soal: essay, pilihan ganda, checkbox, tanggal & waktu, benar/salah
- **Publikasi & Bagikan** — link publik dengan custom short code, QR code, dan proteksi token
- **Pengisian Form** — timer dengan auto-submit, shuffle soal/jawaban, satu respons per orang
- **Analisis** — statistik respons, skor, dan export ke Excel/PDF
- **Autentikasi** — JWT dengan verifikasi OTP via email, refresh token, dan lupa password
- **Admin & Moderasi** — takedown/restore form, kelola user, feedback pengguna

## Arsitektur Singkat

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

## Mulai Cepat

### 1. Jalankan Backend API

Prasyarat: [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) dan SQL Server.

```bash
cd api
cp .env.example .env        # lalu isi DB_CONNECTION, JWT_KEY, SMTP_*
dotnet ef database update   # buat schema database
dotnet run                  # jalan di http://localhost:5000
```

Swagger UI tersedia di `http://localhost:5000/swagger`. Panduan lengkap: [`api/README.md`](./api/README.md).

### 2. Jalankan Aplikasi Mobile

Prasyarat: [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
cd mobile
cp .env.example .env        # atur API_BASE_URL (Android emulator: http://10.0.2.2:5000/api)
flutter pub get
flutter run                 # pilih device yang tersedia
```

Panduan lengkap: [`mobile/README.md`](./mobile/README.md).

### 3. Jalankan Web Frontend

Prasyarat: [Node.js](https://nodejs.org) (rekomendasi versi LTS terbaru).

```bash
cd web/form-fe
npm install
npm run dev                 # jalan di http://localhost:5173
```

> Catatan: CORS di backend sudah mengizinkan `http://localhost:5173` dan `http://localhost:3000`.

## Struktur Repository

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

## Dokumentasi

- **API**: [`api/documentation/`](./api/documentation/) — endpoint, autentikasi, data model, status code, mekanisme keamanan, deployment
- **Mobile**: [`mobile/documentation/`](./mobile/documentation/) — konsumsi API, autentikasi, penanganan error, alur form link
- **Konvensi agent/kodebase**: [`AGENTS.md`](./AGENTS.md)

## Kontribusi

1. Fork repository ini
2. Buat branch fitur (`git checkout -b feature/nama-fitur`)
3. Commit perubahan (`git commit -m 'Tambah fitur X'`)
4. Push ke branch (`git push origin feature/nama-fitur`)
5. Buka Pull Request

## License

Project ini proprietary dan confidential.

---

Dibuat dengan 💙 oleh FormUp Team
