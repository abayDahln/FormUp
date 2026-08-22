# FormUp API

![.NET](https://img.shields.io/badge/.NET-8.0-blue)
![ASP.NET Core](https://img.shields.io/badge/ASP.NET%20Core-8.0-purple)
![Entity Framework](https://img.shields.io/badge/Entity%20Framework%20Core-8.0-green)
![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-red)

## Tentang FormUp API

FormUp API adalah layanan backend untuk platform FormUp — aplikasi pembuat form yang mirip Google Forms dan Quizizz. API ini memungkinkan pengguna membuat form, membagikan link, dan mengumpulkan response dengan mudah. Cocok untuk survey, kuis, polling, ujian, dan berbagai jenis form lainnya.

## Fitur Utama

- **Kelola Form**: Buat, edit, publikasi (draft → published → closed), duplicate, dan atur form
- **Tipe Pertanyaan**: essay, pilihan ganda, checkbox, tanggal & waktu, benar/salah (reference table di database)
- **Kumpulkan Response**: respons publik via link/QR dengan proteksi token, timer, dan skor
- **Analisis & Export**: statistik respons dan export Excel/PDF
- **Autentikasi**: JWT + verifikasi OTP email saat registrasi, refresh token, lupa/reset password
- **Admin**: kelola user (ban/activate), moderasi form (takedown/restore), feedback pengguna

## Teknologi

| Bagian | Teknologi |
|--------|-----------|
| Framework | ASP.NET Core 8.0 |
| Database | SQL Server + Entity Framework Core 8 |
| Autentikasi | JWT Bearer (`System.IdentityModel.Tokens.Jwt`) |
| Password hashing | PBKDF2 SHA256, 100.000 iterasi |
| API Docs | Swagger/OpenAPI (Swashbuckle) |
| Konfigurasi | DotNetEnv (`.env`) + `appsettings.json` |
| File storage | Local (`wwwroot/uploads`), disajikan via static files |
| Email OTP | SMTP (default Gmail) |
| Lainnya | QRCoder (QR code), ClosedXML/QuestPDF (export), PdfPig (import Word/PDF) |

## Struktur Folder

```
api/
├── Controllers/        # Admin, Analytics, Auth, Feedbacks, Forms,
│                       # PublicForms, Questions, References, Responses,
│                       # Templates, Users
├── Models/             # Entitas EF Core, DTOs, FormUpDbContext
├── Services/           # JwtService, EmailService, ErrorHandlingMiddleware, dll.
├── Migrations/         # Migrasi EF Core
├── Properties/         # launchSettings.json
├── wwwroot/uploads/    # File upload user
├── documentation/      # Dokumentasi API (Bahasa Indonesia)
├── appsettings.json
├── .env.example        # Template environment variable
└── FormUpAPI.csproj
```

## Mulai dari Nol

### Prasyarat

- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) atau lebih baru
- SQL Server (LocalDB, Express, atau Developer edition) — mis. via [SQL Server 2022 Express](https://www.microsoft.com/sql-server/sql-server-downloads)
- [dotnet-ef tool](https://learn.microsoft.com/en-us/ef/core/cli/dotnet): `dotnet tool install --global dotnet-ef`
- Git

### Cara Install

**1. Clone repository** (dari root repo):

```bash
git clone <url-repo-anda>.git
cd FormUp/api
```

**2. Restore dependency**

```bash
dotnet restore
```

**3. Buat file `.env`** — salin dari template lalu isi nilai:

```bash
cp .env.example .env
```

Isi file `.env`:

```dotenv
# Koneksi database (WAJIB)
DB_CONNECTION=Server=localhost;Database=FormUpDb;Trusted_Connection=True;TrustServerCertificate=True

# Kunci signing JWT (WAJIB) - minimal 32 karakter, WAJIB diganti di production
JWT_KEY=ganti-dengan-kunci-acak-minimal-32-karakter

# SMTP untuk kirim OTP email (WAJIB untuk register & lupa password)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=email-anda@gmail.com
SMTP_PASS=password-aplikasi-gmail
SMTP_FROM=email-anda@gmail.com

# URL publik untuk share link form
PUBLIC_URL=https://formup.my.id
```

> **Prioritas konfigurasi**: env var (`DB_CONNECTION`, `JWT_KEY`, `SMTP_*`) menimpa nilai di `appsettings.json`. Section JWT di appsettings bernama **`Jwt`** (bukan `JwtSettings`). Aplikasi menolak startup jika `JWT_KEY` masih nilai default atau kurang dari 32 karakter.
>
> **Catatan Gmail**: gunakan *App Password* (bukan password akun) — aktifkan 2FA lalu buat di https://myaccount.google.com/apppasswords.

**4. Setup database**

```bash
dotnet ef database update
```

Perintah ini membuat semua tabel sesuai migrasi EF Core di database `FormUpDb`.

**5. Jalankan aplikasi**

```bash
dotnet run
```

API berjalan di **http://localhost:5000**, Swagger UI di **http://localhost:5000/swagger** (browser akan terbuka otomatis pada profile `http`).

## Quick Start API

### Base URL

```
http://localhost:5000/api
```

### Autentikasi

Semua request (kecuali endpoint auth publik seperti login/register/OTP) butuh token JWT di header:

```
Authorization: Bearer <your-jwt-token>
```

Token access berlaku 14 hari secara default (`Jwt:AccessTokenMinutes = 20160`); perbarui via `POST /api/auth/refresh`. Token yang sudah kedaluwarsa masih bisa di-refresh hingga 7 hari — user tidak perlu login ulang selama 1–2 minggu.

### Contoh: Buat Form Baru

```bash
curl -X POST http://localhost:5000/api/forms \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Survey Kepuasan",
    "description": "Tolong isi survey ini"
  }'
```

### Tipe Pertanyaan yang Didukung

ID tipe merujuk ke reference table `QuestionType` di database (dapat dicek via `GET /api/references/question-types`):

| ID | Tipe | Keterangan |
|----|------|------------|
| 1 | Essay | Input teks panjang |
| 2 | Pilihan Ganda | Pilih satu dari beberapa opsi |
| 3 | Checkbox | Pilih lebih dari satu opsi |
| 4 | Tanggal & Waktu | Pemilih tanggal/waktu |
| 5 | Benar/Salah | Jawaban true/false |

## Development

### Build untuk Production

```bash
dotnet publish -c Release -o ./publish
```

> Project ini belum memiliki unit test — perintah `dotnet test` akan gagal karena belum ada test project.

### Database Migrations

```bash
# Tambah migration baru
dotnet ef migrations add AddNewFeature

# Update database
dotnet ef database update

# Hapus migration terakhir (yang belum di-apply)
dotnet ef migrations remove
```

## Dokumentasi API

Dokumentasi lengkap tersedia di folder [`documentation/`](./documentation/):

- **[API Endpoints](./documentation/api_endpoints.md)** — daftar semua endpoint dengan request/response
- **[Autentikasi](./documentation/api_authentication.md)** — register + OTP, login, refresh, lupa password
- **[Data Models](./documentation/data_models.md)** — struktur data dan skema database
- **[Status Codes](./documentation/api_status_code.md)** — penjelasan HTTP status codes
- **[Konsep](./documentation/concepts.md)** — konsep inti platform
- **[Mekanisme Keamanan](./documentation/mechanisms.md)** — rate limiting, token, proteksi
- **[Alur Link Form](./documentation/form_link_flow.md)** — share link & short code
- **[Admin Endpoint](./documentation/admin_endpoint.md)** — endpoint admin & moderasi
- **[Deployment](./documentation/deployment.md)** — setup production
- **[Requirements](./documentation/requirements.md)** — spesifikasi project
- **[Fitur Mendatang](./documentation/future_features.md)** — roadmap fitur

## Performance Target

- API Response Time: < 200ms (p95)
- Concurrent Users: 10,000+
- Uptime SLA: 99.9%
- File Upload Limit: 10MB per file

## Contributing

1. Fork repository
2. Buat branch fitur (`git checkout -b feature/nama-fitur`)
3. Commit changes (`git commit -m 'Tambah fitur baru'`)
4. Push ke branch (`git push origin feature/nama-fitur`)
5. Buat Pull Request

### Standar Kode

- Ikuti prinsip Clean Code
- Gunakan async/await untuk I/O operations
- Semua response dibungkus `ApiResponse<T>` (`Status`, `Message`, `Data`)
- Soft delete via kolom `deleted_at` pada entitas utama
- Kolom database `snake_case` via Fluent API di `FormUpDbContext`

## License

Project ini proprietary dan confidential.

---

Dibuat dengan 💙 oleh FormUp Team
