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

---

# Instalasi dari Nol

## Prasyarat (Semua OS)

| Kebutuhan | Keterangan |
|-----------|------------|
| [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) | Wajib — runtime saja tidak cukup saat development (butuh `dotnet-ef`) |
| SQL Server 2019+ | LocalDB / Express / Developer / Full — lihat per-OS di bawah |
| [dotnet-ef tool](https://learn.microsoft.com/en-us/ef/core/cli/dotnet) | `dotnet tool install --global dotnet-ef` |
| Git | Untuk clone repository |
| SMTP account | Gmail App Password untuk kirim OTP (opsional saat development) |

Verifikasi setelah install:

```bash
dotnet --version          # harus 8.0.x atau lebih baru
dotnet ef --version       # harus terpasang
```

## 1. Install .NET SDK & Database

### 🪟 Windows

**.NET SDK** — pilih salah satu:

```powershell
# Via winget (recommended)
winget install Microsoft.DotNet.SDK.8

# Atau via Chocolatey
choco install dotnet-sdk

# Atau download installer langsung:
# https://dotnet.microsoft.com/download/dotnet/8.0
```

**SQL Server** — pilih salah satu:

| Opsi | Cara | Cocok untuk |
|------|------|-------------|
| LocalDB (paling ringan) | Ikut [SQL Server Express](https://www.microsoft.com/sql-server/sql-server-downloads), centang LocalDB | Development cepat, tanpa konfigurasi |
| SQL Server Express | Installer di link atas, pilih Basic | Development + production kecil |
| Developer Edition | Installer sama, pilih Custom → Developer | Fitur lengkap gratis (non-production license) |

Pastikan layanan **SQL Server (MSSQLSERVER)** berstatus *Running* (cek `services.msc`). Ini penyebab umum error `503 Layanan sedang tidak tersedia`.

### 🍎 macOS

**.NET SDK**:

```bash
brew install --cask dotnet-sdk
```

**SQL Server** — ⚠️ tidak ada SQL Server native untuk macOS, gunakan **Docker**:

```bash
# Install Docker Desktop dari https://www.docker.com/products/docker-desktop/
# lalu jalankan container SQL Server 2022:
docker run -e "ACCEPT_EULA=Y" \
  -e "MSSQL_SA_PASSWORD=FormUpStrong!123" \
  -p 1433:1433 \
  --name formup-sqlserver \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

> Password harus memenuhi kebijakan kompleksitas SQL Server (huruf besar, kecil, angka, simbol, min. 8 karakter).

### 🐧 Linux (Ubuntu 22.04/24.04)

**.NET SDK**:

```bash
sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0
```

(untuk distro lain lihat https://learn.microsoft.com/en-us/dotnet/core/install/linux)

**SQL Server** — dua pilihan:

```bash
# Opsi A: Docker (paling mudah, sama seperti macOS di atas)
docker run -e "ACCEPT_EULA=Y" \
  -e "MSSQL_SA_PASSWORD=FormUpStrong!123" \
  -p 1433:1433 \
  --name formup-sqlserver \
  -d mcr.microsoft.com/mssql/server:2022-latest

# Opsi B: SQL Server native di Ubuntu
# ikuti panduan resmi:
# https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-ubuntu
```

**dotnet-ef tool** (semua OS):

```bash
dotnet tool install --global dotnet-ef
```

> Jika perintah `dotnet ef` tidak dikenali, tambahkan `~/.dotnet/tools` ke `PATH`.

## 2. Clone & Restore

```bash
git clone <url-repo-anda>.git
cd FormUp/api
dotnet restore
```

## 3. Konfigurasi `.env`

Salin template lalu isi:

```bash
cp .env.example .env
```

Isi file `.env`:

```dotenv
# Koneksi database (WAJIB)
# Windows + LocalDB:
DB_CONNECTION=Server=(localdb)\MSSQLLocalDB;Database=FormUpDb;Trusted_Connection=True;TrustServerCertificate=True
# Windows + SQL Server (instance default):
# DB_CONNECTION=Server=localhost;Database=FormUpDb;Trusted_Connection=True;TrustServerCertificate=True
# macOS / Linux (Docker):
# DB_CONNECTION=Server=localhost,1433;Database=FormUpDb;User Id=sa;Password=FormUpStrong!123;TrustServerCertificate=True

# Kunci signing JWT (WAJIB) — minimal 32 karakter acak
# Generate: openssl rand -base64 48  (macOS/Linux)
#           node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"  (semua OS)
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

## 4. Migrasi Database

Perintah ini membuat database `FormUpDb` beserta seluruh tabel sesuai migrasi EF Core di folder `Migrations/`:

```bash
dotnet ef database update
```

Jika sukses akan muncul `Applying migration ... Done.` Periksa lewat SSMS / Azure Data Studio / `sqlcmd` — tabel `User`, `Form`, `Question`, `Response`, dst. sudah ada.

Troubleshooting umum:

| Error | Penyebab & solusi |
|-------|-------------------|
| `A network-related or instance-specific error` | SQL Server tidak jalan — cek service (`services.msc` di Windows) atau `docker ps` untuk container |
| `Cannot open database "FormUpDb"` | Koneksi OK tapi izin kurang — pakai kredensial `sa`/admin, atau buat database manual sekali |
| `Login failed for user 'sa'` | Password salah di `DB_CONNECTION`, atau password SA tidak sesuai kebijakan kompleksitas |
| `dotnet ef: command not found` | Install ulang tool + pastikan `~/.dotnet/tools` ada di `PATH` |

Perintah migrasi lain:

```bash
# Tambah migration baru (saat mengubah Models/)
dotnet ef migrations add AddNewFeature

# Hapus migration terakhir (yang belum di-apply)
dotnet ef migrations remove

# Lihat daftar migration & status
dotnet ef migrations list
```

## 5. Jalankan

```bash
dotnet run
```

- API: **http://localhost:5000**
- Swagger UI: **http://localhost:5000/swagger**

Set port/URL manual (opsional):

```bash
# macOS/Linux
ASPNETCORE_URLS=http://localhost:5000 dotnet run

# Windows PowerShell
$env:ASPNETCORE_URLS="http://localhost:5000"; dotnet run
```

---

# Quick Start API

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

---

# Deploy ke PC Server

Prasyarat server: satu mesin Windows/Linux (atau VPS) dengan akses admin/sudo, domain (opsional tapi disarankan untuk HTTPS).

## Langkah 1 — Siapkan Runtime & Database di Server

Install di server (bukan SDK — cukup **ASP.NET Core Runtime 8**):

```bash
# Ubuntu
sudo apt-get install -y aspnetcore-runtime-8.0

# Windows: download "ASP.NET Core Runtime 8.0 Hosting Bundle" (wajib jika pakai IIS)
# https://dotnet.microsoft.com/download/dotnet/8.0
```

Siapkan SQL Server di server (atau gunakan server DB terpisah):
- **Windows**: install SQL Server Express/Developer, pastikan service Running dan TCP/IP aktif (SQL Server Configuration Manager).
- **Linux**: SQL Server native atau Docker (perintah sama seperti bagian instalasi di atas).

Buat database kosong (migrasi bisa membuatkan tabelnya otomatis):

```sql
CREATE DATABASE FormUpDb;
```

## Langkah 2 — Publish Aplikasi

Di mesin development:

```bash
cd api

# Framework-dependent (butuh runtime di server, output lebih kecil)
dotnet publish -c Release -o ./publish

# ATAU self-contained (tidak butuh .NET terpasang di server, output lebih besar)
dotnet publish -c Release -r linux-x64 --self-contained true -o ./publish-linux
dotnet publish -c Release -r win-x64   --self-contained true -o ./publish-win
```

Salin isi folder `publish` ke server, mis. `/var/www/formup-api` (Linux) atau `C:\inetpub\formup-api` (Windows). Jangan lupa sertakan juga folder `Migrations/` jika ingin menjalankan migrasi dari server.

> Project ini belum memiliki unit test — perintah `dotnet test` akan gagal karena belum ada test project.

## Langkah 3 — Environment Production di Server

JANGAN menyimpan secret di `appsettings.json`. Di server buat file `.env` di folder aplikasi (format sama seperti development) atau set env var sistem:

```bash
# Linux (/etc/environment atau systemd unit di bawah)
export ASPNETCORE_ENVIRONMENT=Production
export ASPNETCORE_URLS=http://localhost:5000          # API hanya listen lokal, proxy yang expose ke publik
export DB_CONNECTION="Server=localhost,1433;Database=FormUpDb;User Id=sa;Password=<password-db-produksi>;TrustServerCertificate=True"
export JWT_KEY="<kunci-acak-minimal-32-karakter-yang-different-dari-development>"
export SMTP_HOST=smtp.gmail.com
export SMTP_PORT=587
export SMTP_USER=email-produksi@gmail.com
export SMTP_PASS=<app-password>
export SMTP_FROM=email-produksi@gmail.com
export PUBLIC_URL=https://formup.my.id
```

Update juga `AllowedOrigins` di `appsettings.json` dengan domain frontend produksi (mis. `https://formup.my.id`).

## Langkah 4 — Migrasi Database Produksi

Dari mesin development (menunjuk langsung ke DB server):

```bash
dotnet ef database update --connection "Server=<ip-server>,1433;Database=FormUpDb;User Id=sa;Password=<password>;TrustServerCertificate=True"
```

Atau dari folder publish di server (jika menyertakan tool ef):

```bash
dotnet ef database update --connection "<DB_CONNECTION produksi>"
```

## Langkah 5 — Jalankan sebagai Service (Auto-restart & Boot)

### 🐧 Linux — systemd

Buat `/etc/systemd/system/formup-api.service`:

```ini
[Unit]
Description=FormUp API
After=network.target mssql-server.service

[Service]
WorkingDirectory=/var/www/formup-api
ExecStart=/usr/bin/dotnet /var/www/formup-api/FormUpAPI.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=formup-api
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:5000
# Alternatif file .env: baris Environment= di sini untuk tiap variabel rahasia

[Install]
WantedBy=multi-user.target
```

Aktifkan:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now formup-api
sudo systemctl status formup-api     # pastikan active (running)
journalctl -u formup-api -f          # lihat log live
```

### 🪟 Windows — Windows Service / IIS

**Opsi A: Windows Service** (paling sederhana tanpa IIS):

```powershell
sc.exe create "FormUpAPI" binPath= "C:\inetpub\formup-api\FormUpAPI.exe" start= auto
sc.exe start "FormUpAPI"
```

Set environment variable sistem (System Properties → Environment Variables) atau gunakan file `.env` di folder aplikasi.

**Opsi B: IIS**: pasang *Hosting Bundle*, buat site baru yang menunjuk ke folder aplikasi, set Application Pool **No Managed Code**. Port/HTTPS diatur via binding IIS.

## Langkah 6 — Reverse Proxy + HTTPS

API hanya listen di `localhost:5000`; reverse proxy yang mengekspos ke publik dengan SSL.

### 🐧 Nginx (Linux)

```nginx
server {
    server_name api.formup.my.id;

    location / {
        proxy_pass         http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        # Naikkan batas upload agar upload file (max 20 MB) tidak ditolak proxy
        client_max_body_size 25M;
    }
}
```

Pasang HTTPS gratis via Let's Encrypt:

```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.formup.my.id
sudo ufw allow 'Nginx Full'   # buka port 80/443
```

### 🪟 Windows

IIS menangani SSL langsung via binding HTTPS (import certificate di IIS Manager). Untuk testing internal, aplikasi juga bisa diakses langsung di `http://<ip-server>:5000` setelah membuka port di Windows Defender Firewall.

## Checklist Pasca-Deploy

- [ ] `curl http://localhost:5000/swagger` di server merespons
- [ ] Akses via domain publik + HTTPS valid
- [ ] Register user baru berhasil (email OTP masuk → SMTP benar)
- [ ] Login mengembalikan token; endpoint terproteksi bisa diakses
- [ ] Upload file tersimpan di `wwwroot/` dan bisa diakses (pastikan folder writable oleh user service: `chown -R www-data:www-data /var/www/formup-api/wwwroot`)
- [ ] CORS: frontend di domain lain bisa memanggil API (`AllowedOrigins`)
- [ ] Backup otomatis database SQL Server terjadwal

---

# Dokumentasi API

Dokumentasi lengkap tersedia di folder [`documentation/`](./documentation/):

- **[API Endpoints](./documentation/api_endpoints.md)** — index endpoint, detail per grup di [`documentation/endpoints/`](./documentation/endpoints/)
- **[Autentikasi](./documentation/api_authentication.md)** — register + OTP, login, refresh, lupa password
- **[Data Models](./documentation/data_models.md)** — struktur data dan skema database
- **[Status Codes](./documentation/api_status_code.md)** — HTTP status codes & rate limiting
- **[Konsep](./documentation/concepts.md)** — konsep inti platform
- **[Mekanisme Keamanan](./documentation/mechanisms.md)** — rate limiting, token, proteksi
- **[Alur Link Form](./documentation/form_link_flow.md)** — share link & short code
- **[Admin Endpoint](./documentation/admin_endpoint.md)** — endpoint admin & moderasi
- **[Deployment](./documentation/deployment.md)** — ringkasan setup production
- **[Fitur Mendatang](./documentation/future_features.md)** — roadmap fitur

# Performance Target

- API Response Time: < 200ms (p95)
- Concurrent Users: 10,000+
- Uptime SLA: 99.9%
- File Upload Limit: 10MB per file

# Contributing

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

# License

Project ini proprietary dan confidential.

---

Dibuat dengan 💙 oleh FormUp Team
