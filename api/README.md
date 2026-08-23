# FormUp API

![.NET](https://img.shields.io/badge/.NET-8.0-blue)
![ASP.NET Core](https://img.shields.io/badge/ASP.NET%20Core-8.0-purple)
![Entity Framework Core](https://img.shields.io/badge/EF%20Core-8.0-green)
![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-red)
![License](https://img.shields.io/badge/License-Proprietary-lightgrey)

Backend REST untuk **FormUp** — platform pembuat form ala Google Forms/Quizizz. API ini menangani autentikasi (JWT + OTP email), manajemen form dan soal (termasuk impor soal dari file `.docx`/`.pdf`/`.xlsx`/`.csv`), pengumpulan respons publik via link/QR, analitik dengan skor otomatis, export CSV/PDF/Excel, serta moderasi admin.

---

## Daftar Isi

- [Prasyarat](#prasyarat)
- [Quick Start (Development)](#quick-start-development)
- [Deployment ke Server Produksi](#deployment-ke-server-produksi)
- [Troubleshooting](#troubleshooting)
- [Fitur Utama](#fitur-utama)
- [Dokumentasi Lengkap](#dokumentasi-lengkap)
- [Kontribusi](#kontribusi)
- [Lisensi](#lisensi)

---

## Prasyarat

| Kebutuhan | Versi | Wajib |
|-----------|-------|-------|
| .NET SDK | 8.0 | Ya |
| SQL Server | 2019+ | Ya |
| dotnet-ef tool | 8.x | Ya |
| Git | terbaru | Ya |
| Akun SMTP | Gmail App Password | Untuk fitur register/reset password |

Verifikasi instalasi:

```bash
$ dotnet --version      # output: 8.0.xxx
$ dotnet ef --version   # output: 8.0.x
```

### Windows

Install .NET SDK:

```powershell
> winget install Microsoft.DotNet.SDK.8
```

Install salah satu edisi SQL Server:

| Opsi | Perintah / Sumber | Cocok untuk |
|------|-------------------|-------------|
| LocalDB | Ikut installer [SQL Server Express](https://www.microsoft.com/sql-server/sql-server-downloads), centang LocalDB | Development cepat, tanpa konfigurasi |
| Express | Installer di atas, mode Basic | Development + production kecil |
| Developer | Installer di atas, mode Custom → Developer | Fitur lengkap, gratis non-production |

Pastikan layanan berjalan:

```powershell
> Get-Service MSSQLSERVER   # Status harus Running
```

### macOS

.NET SDK tidak tersedia sebagai native build untuk SQL Server di macOS — database dijalankan lewat Docker.

```bash
$ brew install --cask dotnet-sdk
```

Jalankan SQL Server 2022 via container:

```bash
$ docker run -e "ACCEPT_EULA=Y" \
    -e "MSSQL_SA_PASSWORD=FormUpStrong!123" \
    -p 1433:1433 --name formup-sqlserver \
    -d mcr.microsoft.com/mssql/server:2022-latest
```

> **Catatan**: password SA wajib memenuhi kebijakan kompleksitas SQL Server (huruf besar, huruf kecil, angka, simbol, minimal 8 karakter).

### Linux (Ubuntu 22.04/24.04)

```bash
$ sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0
```

SQL Server — pilih Docker (paling cepat) atau [instalasi native Ubuntu](https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-ubuntu):

```bash
$ docker run -e "ACCEPT_EULA=Y" \
    -e "MSSQL_SA_PASSWORD=FormUpStrong!123" \
    -p 1433:1433 --name formup-sqlserver \
    -d mcr.microsoft.com/mssql/server:2022-latest
```

### Semua OS — dotnet-ef

```bash
$ dotnet tool install --global dotnet-ef
```

Jika `dotnet ef` tidak dikenali, tambahkan `~/.dotnet/tools` (Linux/macOS) atau `%USERPROFILE%\.dotnet\tools` (Windows) ke `PATH`.

---

## Quick Start (Development)

Jalankan semua perintah dari folder `api/`.

### 1. Clone & Restore Dependency

```bash
$ git clone <url-repo-anda>.git
$ cd FormUp/api
$ dotnet restore
```

### 2. Konfigurasi Environment

Salin template lalu isi nilainya:

```bash
$ cp .env.example .env
```

Isi file `.env`:

```dotenv
# WAJIB — koneksi SQL Server.
# Windows LocalDB:
DB_CONNECTION=Server=(localdb)\MSSQLLocalDB;Database=FormUpDb;Trusted_Connection=True;TrustServerCertificate=True
# Windows instance default:
# DB_CONNECTION=Server=localhost;Database=FormUpDb;Trusted_Connection=True;TrustServerCertificate=True
# macOS/Linux (Docker):
# DB_CONNECTION=Server=localhost,1433;Database=FormUpDb;User Id=sa;Password=FormUpStrong!123;TrustServerCertificate=True

# WAJIB — kunci signing JWT, minimal 32 karakter acak. Generate:
#   Linux/macOS : openssl rand -base64 48
#   Node        : node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"
JWT_KEY=<kunci-acak-minimal-32-karakter>

# WAJIB untuk register & reset password — kirim OTP email
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=email-anda@gmail.com
SMTP_PASS=<app-password-gmail>
SMTP_FROM=email-anda@gmail.com

# URL publik yang dipakai menyusun share link form
PUBLIC_URL=https://formup.my.id
```

Variabel lengkap:

| Variabel | Wajib | Fungsi |
|----------|-------|--------|
| `DB_CONNECTION` | Ya | Connection string SQL Server; menimpa `ConnectionStrings:DefaultConnection` |
| `JWT_KEY` | Ya | Kunci signing JWT; menimpa `Jwt:Key`. Aplikasi **menolak startup** jika masih nilai default atau < 32 karakter |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` / `SMTP_FROM` | Ya* | Kirim email OTP; menimpa section `Smtp` |
| `PUBLIC_URL` | Tidak | Base URL share link `/f/{code}` |

\* Wajib untuk alur register/login/lupa password.

> **Catatan**: JANGAN menyimpan secret di `appsettings.json` — file itu masuk repository. Gunakan `.env` (gitignored) atau environment variable sistem.
>
> **Catatan Gmail**: gunakan *App Password*, bukan password akun. Aktifkan 2FA lalu buat di https://myaccount.google.com/apppasswords.

### 3. Migrasi Database

```bash
$ dotnet ef database update
```

Perintah ini membuat database `FormUpDb` beserta seluruh tabel sesuai migrasi di `Migrations/`.

### 4. Jalankan API

```bash
$ dotnet run
```

- API: **http://localhost:5000**
- Swagger UI: **http://localhost:5000/swagger**

Port default `5000` berasal dari launch profile `http` (`Properties/launchSettings.json`). Ubah dengan:

```bash
$ ASPNETCORE_URLS=http://localhost:5050 dotnet run          # Linux/macOS
> $env:ASPNETCORE_URLS="http://localhost:5050"; dotnet run  # PowerShell
```

### 5. Uji Cepat

Buka Swagger UI di browser, atau daftar user via cURL:

```bash
$ curl -X POST http://localhost:5000/api/auth/register \
    -H "Content-Type: application/json" \
    -d '{"fullname":"John Doe","email":"john@example.com","password":"SecurePass123!"}'
```

OTP verifikasi dikirim ke email — selesaikan registrasi via `POST /api/auth/verify-registration`.

---

## Deployment ke Server Produksi

Prasyarat server: mesin/VPS Windows atau Linux, akses admin/sudo, domain + DNS mengarah ke server (untuk HTTPS).

### 1. Persiapan Server

Install **runtime** (bukan SDK) dan siapkan SQL Server:

```bash
# Ubuntu — ASP.NET Core Runtime 8
$ sudo apt-get install -y aspnetcore-runtime-8.0
```

Windows: download **ASP.NET Core Runtime 8.0 Hosting Bundle** dari https://dotnet.microsoft.com/download/dotnet/8.0 — wajib jika memakai IIS.

Siapkan SQL Server (native atau Docker — sama seperti bagian Prasyarat), lalu buat database kosong:

```sql
CREATE DATABASE FormUpDb;
```

### 2. Build & Publish Aplikasi

Di mesin development, dari folder `api/`:

```bash
# Framework-dependent — butuh runtime .NET di server, ukuran kecil
$ dotnet publish -c Release -o ./publish

# Self-contained — tidak butuh .NET terpasang di server, ukuran besar
$ dotnet publish -c Release -r linux-x64 --self-contained true -o ./publish-linux
$ dotnet publish -c Release -r win-x64   --self-contained true -o ./publish-win
```

### 3. Transfer File ke Server

Salin isi folder `publish` ke server. Lokasi yang disarankan:

```text
Linux  : /var/www/formup-api
Windows: C:\inetpub\formup-api
```

```bash
# Contoh via scp (dari mesin development)
$ scp -r ./publish/* user@<ip-server>:/var/www/formup-api/
```

Sertakan folder `Migrations/` jika migrasi akan dijalankan dari server.

### 4. Konfigurasi `.env` di Server

Buat file `.env` di folder aplikasi dengan nilai produksi:

```dotenv
ASPNETCORE_ENVIRONMENT=Production
DB_CONNECTION=Server=localhost,1433;Database=FormUpDb;User Id=sa;Password=<password-db-produksi>;TrustServerCertificate=True
JWT_KEY=<kunci-produksi-acak-minimal-32-karakter>
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=email-produksi@gmail.com
SMTP_PASS=<app-password>
SMTP_FROM=email-produksi@gmail.com
PUBLIC_URL=https://api.formup.my.id
```

Update CORS di `appsettings.json` pada folder publish — ganti `AllowedOrigins` dengan domain frontend produksi:

```json
"AllowedOrigins": [
  "https://formup.my.id"
]
```

> **Catatan**: JANGAN menyimpan rahasia di `appsettings.json`. Secret hanya boleh ada di `.env` (permission terbatas: `chmod 600 .env`) atau environment variable sistem.

### 5. Jalankan Migrasi Database

Dari mesin development, menunjuk langsung ke database produksi:

```bash
$ dotnet ef database update --connection "Server=<ip-server>,1433;Database=FormUpDb;User Id=sa;Password=<password>;TrustServerCertificate=True"
```

### 6. Jalankan sebagai Service

#### 🐧 Linux — systemd

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

[Install]
WantedBy=multi-user.target
```

Aktifkan dan cek status:

```bash
$ sudo systemctl daemon-reload
$ sudo systemctl enable --now formup-api
$ sudo systemctl status formup-api     # harus active (running)
$ journalctl -u formup-api -f          # log live
```

Beri izin tulis untuk upload file:

```bash
$ sudo chown -R www-data:www-data /var/www/formup-api/wwwroot
```

#### 🪟 Windows — Windows Service atau IIS

**Opsi A — Windows Service** (tanpa IIS):

```powershell
> sc.exe create "FormUpAPI" binPath= "C:\inetpub\formup-api\FormUpAPI.exe" start= auto
> sc.exe start "FormUpAPI"
> sc.exe query "FormUpAPI"   # STATE harus RUNNING
```

Set environment variable melalui *System Properties → Environment Variables*, atau gunakan `.env` di folder aplikasi.

**Opsi B — IIS**: pasang Hosting Bundle, buat Site baru yang menunjuk ke folder aplikasi, set Application Pool ke **No Managed Code**, atur binding HTTPS di IIS Manager.

### 7. Reverse Proxy + HTTPS

API hanya listen di `localhost:5000` — reverse proxy yang mengeksposnya ke publik.

#### Nginx (Linux)

Buat `/etc/nginx/sites-available/formup-api`:

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
        client_max_body_size 25M;   # ruang untuk upload maksimum (20 MB audio)
    }
}
```

Aktifkan dan pasang HTTPS Let's Encrypt:

```bash
$ sudo ln -s /etc/nginx/sites-available/formup-api /etc/nginx/sites-enabled/
$ sudo nginx -t && sudo systemctl reload nginx
$ sudo apt-get install -y certbot python3-certbot-nginx
$ sudo certbot --nginx -d api.formup.my.id
$ sudo ufw allow 'Nginx Full'
```

#### IIS (Windows)

SSL ditangani langsung oleh IIS melalui site binding HTTPS (import certificate di IIS Manager). Untuk jaringan internal, API juga dapat diakses langsung di `http://<ip-server>:5000` setelah port dibuka di Windows Defender Firewall.

### Checklist Pasca-Deploy

- [ ] `curl http://localhost:5000/swagger` merespons di server
- [ ] Domain publik dapat diakses dengan HTTPS valid
- [ ] Register user baru berhasil — email OTP masuk (SMTP benar)
- [ ] Login mengembalikan token; endpoint terproteksi dapat diakses
- [ ] Upload gambar/audio tersimpan di `wwwroot/` dan dapat dimuat
- [ ] Frontend di domain lain dapat memanggil API (CORS `AllowedOrigins`)
- [ ] Backup otomatis SQL Server terjadwal

---

## Troubleshooting

| Error | Penyebab | Solusi |
|-------|----------|--------|
| `503 Layanan sedang tidak tersedia` | SQL Server mati — middleware menangkap `SqlException` | Windows: start service `MSSQLSERVER`. Docker: `docker start formup-sqlserver` |
| `A network-related or instance-specific error` saat migrasi | Connection string salah / DB tidak jalan | Cek `DB_CONNECTION`, cocokkan host/port/kredensial |
| `Cannot open database "FormUpDb"` | Login tanpa hak membuat DB | Pakai kredensial admin/`sa`, atau jalankan `CREATE DATABASE FormUpDb;` manual |
| `Login failed for user 'sa'` | Password salah / tidak memenuhi kebijakan kompleksitas | Reset password SA atau perbaiki `DB_CONNECTION` |
| Aplikasi berhenti saat startup dengan pesan JWT key | `JWT_KEY` masih default atau < 32 karakter | Generate kunci baru (`openssl rand -base64 48`) dan isi di `.env` |
| OTP email tidak terkirim | SMTP kredensial salah / bukan App Password | Buat App Password Gmail (2FA aktif), pastikan `SMTP_*` terisi |
| `401` terus-menerus dari client | Token kedaluwarsa | Header response berisi `Token-Expired: true` → panggil `POST /api/auth/refresh`, lalu ulangi request |
| Request frontend diblokir CORS | Origin frontend tidak terdaftar | Tambahkan origin ke array `AllowedOrigins` di `appsettings.json`, restart API |
| Upload file gagal `413` | Body size dibatasi proxy | Set `client_max_body_size 25M` di Nginx (atau batas request IIS) |
| Import soal `.docx` gagal dibaca | File rusak / format tidak sesuai template | Unduh template resmi: `GET /api/templates/import-questions?format=csv`; preview akan menampilkan error per baris |
| `429 Too Many Requests` | Melebihi rate limit (`auth` 10/mnt, `creator` 120/mnt, `submit` 60/mnt, `template` 10/mnt) | Backoff eksponensial, retry setelah jeda |
| `dotnet ef: command not found` | Tool belum terpasang / PATH | `dotnet tool install --global dotnet-ef`, tambahkan folder tools ke `PATH` |

---

## Fitur Utama

- **Kelola form** — CRUD, draft → published → closed, settings (timer, token akses, one-response, jadwal buka/tutup), banner, share link + QR code
- **Tipe pertanyaan** — essay, pilihan ganda, checkbox, tanggal & waktu, benar/salah
- **Impor soal** — dari `.xlsx`, `.xls`, `.csv`, `.pdf`, `.docx` dengan alur preview → validasi per baris → simpan; ekstraksi gambar dari dokumen
- **Kumpulkan respons** — publik via link/QR, guest atau login, proteksi token & rate limiting, anti-bocor kunci jawaban
- **Analitik & export** — statistik responden, skor otomatis, pagination + pencarian di level database, export CSV
- **Autentikasi** — JWT 14 hari + refresh 7 hari, OTP email, PBKDF2 SHA256 100.000 iterasi
- **Admin** — kelola user (ban/activate/hapus), moderasi form (takedown/restore), kelola feedback

## Dokumentasi Lengkap

Dokumentasi teknis (Bahasa Indonesia) ada di folder [`documentation/`](./documentation/):

| File | Isi |
|------|-----|
| [`api_endpoints.md`](./documentation/api_endpoints.md) | Index endpoint — detail per grup di [`endpoints/`](./documentation/endpoints/) |
| [`api_authentication.md`](./documentation/api_authentication.md) | Register + OTP, login, refresh, reset password |
| [`data_models.md`](./documentation/data_models.md) | Skema database & entitas EF Core |
| [`api_status_code.md`](./documentation/api_status_code.md) | Format response, HTTP status codes, rate limiting |
| [`concepts.md`](./documentation/concepts.md) | Konsep inti platform |
| [`mechanisms.md`](./documentation/mechanisms.md) | Mekanisme keamanan & load-lightening |
| [`form_link_flow.md`](./documentation/form_link_flow.md) | Alur share link & short code |
| [`admin_endpoint.md`](./documentation/admin_endpoint.md) | Endpoint admin & moderasi |
| [`deployment.md`](./documentation/deployment.md) | Ringkasan setup production |
| [`future_features.md`](./documentation/future_features.md) | Roadmap fitur |

## Kontribusi

1. Fork repository
2. Buat branch fitur: `git checkout -b feature/nama-fitur`
3. Commit perubahan: `git commit -m "Tambah fitur baru"`
4. Push: `git push origin feature/nama-fitur`
5. Buka Pull Request

Standar kode:

- Gunakan async/await untuk operasi I/O
- Bungkus semua response dengan `ApiResponse<T>` (`Status`, `Message`, `Data`)
- Soft delete via kolom `deleted_at`; kolom database `snake_case` via Fluent API di `FormUpDbContext`
- Jalankan `dotnet build` sebelum membuat PR (project ini belum memiliki unit test — `dotnet test` akan gagal karena belum ada test project)

## Lisensi

Proprietary and confidential.
