# FormUp API

![.NET](https://img.shields.io/badge/.NET-8.0-blue)
![ASP.NET Core](https://img.shields.io/badge/ASP.NET%20Core-8.0-purple)
![Entity Framework Core](https://img.shields.io/badge/EF%20Core-8.0-green)
![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-red)
![License](https://img.shields.io/badge/License-Proprietary-lightgrey)

Backend REST untuk **FormUp** — platform pembuat form ala Google Forms/Quizizz. API ini menangani autentikasi (JWT + OTP email), manajemen form dan soal (termasuk impor soal dari file `.docx`/`.pdf`/`.xlsx`/`.csv`), pengumpulan respons publik via link/QR, analitik dengan skor otomatis, export CSV/PDF/Excel, serta moderasi admin.

---

## Daftar Isi

1. [Pengenalan & Fitur](#1-pengenalan--fitur)
2. [Tech Stack](#2-tech-stack)
3. [Instalasi Lengkap](#3-instalasi-lengkap)
   - [Windows](#31-windows)
   - [macOS](#32-macos)
   - [Linux — Ubuntu/Debian](#33-linux--ubuntudebian)
   - [Linux — Arch](#34-linux--arch)
   - [Setup Project (Semua OS)](#35-setup-project-semua-os)
4. [Deployment ke Server Produksi](#4-deployment-ke-server-produksi)
5. [Troubleshooting](#5-troubleshooting)
6. [Dokumentasi, Kontribusi & Lisensi](#6-dokumentasi-kontribusi--lisensi)

---

## 1. Pengenalan & Fitur

### Fitur Utama

- **Kelola form** — CRUD, draft → published → closed, settings (timer, token akses, one-response, jadwal buka/tutup), banner, share link + QR code
- **Tipe pertanyaan** — essay, pilihan ganda, checkbox, tanggal & waktu, benar/salah
- **Impor soal** — dari `.xlsx`, `.xls`, `.csv`, `.pdf`, `.docx` dengan alur preview → validasi per baris → simpan; ekstraksi gambar dari dokumen
- **Kumpulkan respons** — publik via link/QR, guest atau login, proteksi token & rate limiting, anti-bocor kunci jawaban
- **Analitik & export** — statistik responden, skor otomatis, pagination + pencarian di level database, export CSV/Excel/PDF
- **Autentikasi** — JWT 14 hari + refresh 7 hari, OTP email, PBKDF2 SHA256 100.000 iterasi
- **Admin** — kelola user (ban/activate/hapus), moderasi form (takedown/restore), kelola feedback

### Arsitektur

Single project `.csproj` (tanpa class library), 11 controller (`Admin`, `Analytics`, `Auth`, `Feedbacks`, `Forms`, `PublicForms`, `Questions`, `References`, `Responses`, `Templates`, `Users`), `JwtService` + `EmailService` sebagai singleton, response dibungkus `ApiResponse<T>`, soft delete via `deleted_at`, UUID primary key, kolom database `snake_case`.

---

## 2. Tech Stack

| Komponen | Teknologi |
|----------|-----------|
| Runtime | .NET 8.0 (ASP.NET Core Web API) |
| ORM | Entity Framework Core 8 |
| Database | SQL Server 2019+ (LocalDB/Express/Developer/Docker) |
| Auth | JWT Bearer + refresh token, OTP email, PBKDF2 SHA256 |
| Email | SMTP (mis. Gmail App Password) |
| File storage | `wwwroot/uploads` (disajikan via `UseStaticFiles`) |
| API docs | Swagger UI dengan JWT auth (`persistAuthorization`) |

---

## 3. Instalasi Lengkap

### Ringkasan Prasyarat (Semua OS)

| Kebutuhan | Versi | Wajib |
|-----------|-------|-------|
| .NET SDK | 8.0 | Ya |
| SQL Server | 2019+ | Ya |
| dotnet-ef tool | 8.x | Ya |
| Git | terbaru | Ya |
| Akun SMTP | Gmail App Password | Untuk register/reset password |
| Docker | terbaru | macOS & Arch (SQL Server via Docker) |

### 3.1 Windows

#### a. Install .NET SDK 8.0

Via `winget` (PowerShell):

```powershell
> winget install Microsoft.DotNet.SDK.8
```

Atau download installer dari https://dotnet.microsoft.com/download/dotnet/8.0.

#### b. Install SQL Server

Download [SQL Server Express](https://www.microsoft.com/sql-server/sql-server-downloads) lalu pilih salah satu edisi:

| Opsi | Cara | Cocok untuk |
|------|------|-------------|
| **LocalDB** | Ikut installer, centang LocalDB | Development cepat, tanpa konfigurasi |
| **Express** | Installer, mode Basic | Development + production kecil |
| **Developer** | Installer, mode Custom → Developer | Fitur lengkap, gratis non-production |

Pastikan layanan berjalan:

```powershell
> Get-Service MSSQLSERVER   # Status harus Running
```

#### c. Install dotnet-ef

```powershell
> dotnet tool install --global dotnet-ef
```

Jika `dotnet ef` tidak dikenali, tambahkan `%USERPROFILE%\.dotnet\tools` ke `PATH`.

#### d. Verifikasi

```powershell
> dotnet --version      # 8.0.xxx
> dotnet ef --version   # 8.0.x
```

### 3.2 macOS

> .NET SDK tidak tersedia sebagai native build untuk SQL Server di macOS — database dijalankan lewat **Docker**.

#### a. Install Homebrew (jika belum ada)

```bash
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### b. Install .NET SDK 8.0

```bash
$ brew install --cask dotnet-sdk
```

#### c. Install Docker & jalankan SQL Server 2022

Install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) (pilih sesuai chip: Apple Silicon atau Intel), lalu:

```bash
$ docker run -e "ACCEPT_EULA=Y" \
    -e "MSSQL_SA_PASSWORD=FormUpStrong!123" \
    -p 1433:1433 --name formup-sqlserver \
    -d mcr.microsoft.com/mssql/server:2022-latest
```

> **Catatan**: password SA wajib memenuhi kebijakan kompleksitas SQL Server (huruf besar, huruf kecil, angka, simbol, minimal 8 karakter).

Verifikasi container berjalan:

```bash
$ docker ps                                  # formup-sqlserver harus Up
$ docker logs formup-sqlserver --tail 20     # tunggu "SQL Server is now ready"
```

#### d. Install dotnet-ef & verifikasi

```bash
$ dotnet tool install --global dotnet-ef
$ dotnet --version && dotnet ef --version
```

Jika `dotnet ef` tidak dikenali, tambahkan `~/.dotnet/tools` ke `PATH` (di `~/.zshrc` atau `~/.bash_profile`):

```bash
$ export PATH="$PATH:$HOME/.dotnet/tools"
```

### 3.3 Linux — Ubuntu/Debian

#### Ubuntu 22.04/24.04

```bash
$ sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0
```

#### Debian 12

Tambahkan repo Microsoft terlebih dahulu:

```bash
$ sudo apt-get update && sudo apt-get install -y wget
$ wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb
$ sudo dpkg -i packages-microsoft-prod.deb
$ sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0
```

#### SQL Server — pilih salah satu

**Opsi A — Docker (paling cepat, direkomendasikan):**

```bash
$ docker run -e "ACCEPT_EULA=Y" \
    -e "MSSQL_SA_PASSWORD=FormUpStrong!123" \
    -p 1433:1433 --name formup-sqlserver \
    -d mcr.microsoft.com/mssql/server:2022-latest
```

**Opsi B — native Ubuntu (tidak tersedia untuk Debian):**

Ikuti panduan resmi: https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-ubuntu

#### dotnet-ef & verifikasi

```bash
$ dotnet tool install --global dotnet-ef
$ dotnet --version && dotnet ef --version
```

Jika `dotnet ef` tidak dikenali, tambahkan `~/.dotnet/tools` ke `PATH`:

```bash
$ echo 'export PATH="$PATH:$HOME/.dotnet/tools"' >> ~/.bashrc && source ~/.bashrc
```

### 3.4 Linux — Arch

> SQL Server **tidak tersedia native** untuk Arch — wajib pakai **Docker**.

#### a. Install .NET SDK 8.0

```bash
$ sudo pacman -S --needed dotnet-sdk-8.0
```

#### b. Install Docker & jalankan SQL Server 2022

```bash
$ sudo pacman -S --needed docker docker-compose
$ sudo systemctl enable --now docker
$ sudo usermod -aG docker $USER        # logout/login agar docker bisa dipakai tanpa sudo

$ docker run -e "ACCEPT_EULA=Y" \
    -e "MSSQL_SA_PASSWORD=FormUpStrong!123" \
    -p 1433:1433 --name formup-sqlserver \
    -d mcr.microsoft.com/mssql/server:2022-latest
```

> **Catatan Apple Silicon/ARM**: image `mcr.microsoft.com/mssql/server` resmi hanya tersedia untuk `amd64`. Di mesin ARM (mis. Apple Silicon) gunakan flag `--platform linux/amd64` (berjalan via emulasi, lebih lambat):
>
> ```bash
> $ docker run --platform linux/amd64 -e "ACCEPT_EULA=Y" \
>     -e "MSSQL_SA_PASSWORD=FormUpStrong!123" \
>     -p 1433:1433 --name formup-sqlserver \
>     -d mcr.microsoft.com/mssql/server:2022-latest
> ```

#### c. dotnet-ef & verifikasi

```bash
$ dotnet tool install --global dotnet-ef
$ dotnet --version && dotnet ef --version
```

Tambahkan `~/.dotnet/tools` ke `PATH` jika perlu:

```bash
$ echo 'export PATH="$PATH:$HOME/.dotnet/tools"' >> ~/.zshrc && source ~/.zshrc
```

### 3.5 Setup Project (Semua OS)

Jalankan semua perintah dari folder `api/`.

#### 1. Clone & restore dependency

```bash
$ git clone <url-repo-anda>.git
$ cd FormUp/api
$ dotnet restore
```

#### 2. Konfigurasi environment

```bash
$ cp .env.example .env        # Windows: copy .env.example .env
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

> **Catatan Gmail**: gunakan *App Password*, bukan password akun. Aktifkan 2FA lalu buat di https://myaccount.google.com/apppasswords.

#### 3. Migrasi database

```bash
$ dotnet ef database update
```

Perintah ini membuat database `FormUpDb` beserta seluruh tabel sesuai migrasi di `Migrations/`.

#### 4. Jalankan API

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

#### 5. Uji cepat

Buka Swagger UI di browser, atau daftar user via cURL:

```bash
$ curl -X POST http://localhost:5000/api/auth/register \
    -H "Content-Type: application/json" \
    -d '{"fullname":"John Doe","email":"john@example.com","password":"SecurePass123!"}'
```

OTP verifikasi dikirim ke email — selesaikan registrasi via `POST /api/auth/verify-registration`.

#### Perintah EF Core berguna

```bash
$ dotnet ef migrations add <NamaMigrasi>   # buat migrasi baru
$ dotnet ef database update                # terapkan migrasi
$ dotnet ef migrations remove              # batalkan migrasi terakhir
$ dotnet ef migrations list                # daftar migrasi
```

#### Kelola container SQL Server (Docker)

```bash
$ docker stop formup-sqlserver && docker start formup-sqlserver   # stop/start
$ docker rm -f formup-sqlserver                                    # hapus container
$ docker exec -it formup-sqlserver /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "FormUpStrong!123" -C -Q "SELECT @@VERSION"   # uji koneksi
```

---

## 4. Deployment ke Server Produksi

Prasyarat server: mesin/VPS Windows atau Linux, akses admin/sudo, domain + DNS mengarah ke server (untuk HTTPS).

### 1. Persiapan Server

Install **runtime** (bukan SDK) dan siapkan SQL Server:

```bash
# Ubuntu — ASP.NET Core Runtime 8
$ sudo apt-get install -y aspnetcore-runtime-8.0
```

```bash
# Arch — ASP.NET Core Runtime 8
$ sudo pacman -S --needed aspnet-runtime
```

Windows: download **ASP.NET Core Runtime 8.0 Hosting Bundle** dari https://dotnet.microsoft.com/download/dotnet/8.0 — wajib jika memakai IIS.

SQL Server di server: native (Ubuntu/Windows) atau Docker (macOS/Arch/Debian) — sama seperti bagian Instalasi. Lalu buat database kosong:

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

> **Arch**: sesuaikan `User=www-data` → `User=http` (user service default di Arch).

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

Buat `/etc/nginx/sites-available/formup-api` (Arch: letakkan di `/etc/nginx/sites-available/` dan tambahkan `include sites-enabled/*;` di `nginx.conf` atau konfigurasi langsung di `nginx.conf`):

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
$ sudo apt-get install -y certbot python3-certbot-nginx      # Ubuntu/Debian
$ sudo certbot --nginx -d api.formup.my.id
$ sudo ufw allow 'Nginx Full'                                # Ubuntu; Arch: ufw/firewalld sesuai setup
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

## 5. Troubleshooting

| Masalah | Penyebab | Solusi |
|---------|----------|--------|
| Tidak bisa koneksi ke SQL Server | Service/database belum jalan | Windows: `Get-Service MSSQLSERVER`; Docker: `docker ps`, cek log container |
| `dotnet ef: command not found` | Tool belum terpasang / PATH | `dotnet tool install --global dotnet-ef`, tambahkan folder tools ke `PATH` |
| API gagal startup: JWT_KEY | Kunci default / < 32 karakter | Generate kunci acak (`openssl rand -base64 48`) dan isi di `.env` |
| OTP email tidak terkirim | SMTP kredensial salah / bukan App Password | Buat App Password Gmail (2FA aktif), pastikan `SMTP_*` terisi |
| `401` terus-menerus dari client | Token kedaluwarsa | Header response berisi `Token-Expired: true` → panggil `POST /api/auth/refresh`, lalu ulangi request |
| Request frontend diblokir CORS | Origin frontend tidak terdaftar | Tambahkan origin ke array `AllowedOrigins` di `appsettings.json`, restart API |
| Upload file gagal `413` | Body size dibatasi proxy | Set `client_max_body_size 25M` di Nginx (atau batas request IIS) |
| Import soal `.docx` gagal dibaca | File rusak / format tidak sesuai template | Unduh template resmi: `GET /api/templates/import-questions?format=csv`; preview akan menampilkan error per baris |
| `429 Too Many Requests` | Melebihi rate limit (`auth` 10/mnt, `creator` 120/mnt, `submit` 60/mnt, `template` 10/mnt) | Backoff eksponensial, retry setelah jeda |
| Docker: image SQL Server gagal di ARM | Image resmi hanya amd64 | Tambahkan `--platform linux/amd64` saat `docker run` |
| `ACCEPT_EULA` error di log Docker | EULA belum disetujui | Pastikan `-e "ACCEPT_EULA=Y"` ada di perintah `docker run` |

---

## 6. Dokumentasi, Kontribusi & Lisensi

### Dokumentasi Lengkap

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

### Kontribusi

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

### Lisensi

Proprietary and confidential.
