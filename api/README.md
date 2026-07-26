# FormUp API

https://img.shields.io/badge/.NET-8.0-blue
https://img.shields.io/badge/ASP.NET%2520Core-8.0-purple
https://img.shields.io/badge/Entity%2520Framework-8.0-green
https://img.shields.io/badge/SQL%2520Server-2022-red

## Tentang FormUp API

FormUp API adalah layanan backend untuk platform FormUp - sebuah aplikasi pembuat form modern yang mirip Google Forms dan Quizizz. API ini memungkinkan pengguna membuat form, membagikan link, dan mengumpulkan response dengan mudah. Cocok digunakan untuk survey, kuis, polling, ujian, dan berbagai jenis form lainnya.

## Fitur Utama

- **Kelola Form**: Buat, edit, publikasi, dan atur form dengan berbagai tipe pertanyaan
- **Buat Pertanyaan**: Dukung banyak tipe pertanyaan - pilihan ganda, text, rating, checkbox, dropdown, tanggal, waktu, dan upload file
- **Kumpulkan Response**: Lihat response masuk secara real-time dengan status tracking
- **Analisis & Laporan**: Dapatkan statistik lengkap, grafik, dan export data
- **Template**: Pakai template yang sudah siap atau buat template custom sendiri
- **Login Aman**: Autentikasi JWT dengan manajemen role pengguna
- **Bagikan Form**: Dukung link shareable, QR code, dan embed ke website
- **Kontrol Akses**: Pilih form publik, terbatas, atau butuh token khusus

## Struktur Teknologi

### Stack yang Dipakai

| Bagian | Teknologi |
|--------|-----------|
| Framework | ASP.NET Core 8.0 |
| Database | SQL Server 2022 |
| ORM | Entity Framework Core 8.0 |
| Autentikasi | JWT (JSON Web Tokens) |
| Validasi | FluentValidation |
| Logging | Serilog |
| API Docs | Swagger/OpenAPI |
| File Storage | Cloud Storage (S3/GCS) |
| Cache | Redis (opsional) |

### Struktur Folder

```
FormUpAPI/
├── Controllers/
│   └── 
├── Models/
│   ├── User.cs
│   ├── Form.cs
│   ├── FormSetting.cs
│   ├── FormStatus.cs
│   ├── Question.cs
│   ├── QuestionType.cs
│   ├── OptionQuestion.cs
│   ├── Response.cs
│   ├── ResponseStatus.cs
│   ├── RespondentAnswer.cs
│   └── FormUpDbContext.cs
├── Properties/
│   └── launchSettings.json
├── appsettings.json
├── Program.cs
└── FormUpAPI.http
```

## Mulai dari Nol

### Yang Dibutuhkan

- .NET 8.0 SDK atau lebih baru
- SQL Server 2022 atau lebih baru
- Visual Studio 2022 atau VS Code
- Git

### Cara Install

**1. Clone repository**

```bash
git clone https://github.com/yourusername/FormUpAPI.git
cd FormUpAPI
```

**2. Install dependency**

```bash
dotnet restore
```

**3. Atur file appsettings.json**

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=FormUpDb;Trusted_Connection=True;TrustServerCertificate=True;"
  },
  "JwtSettings": {
    "Secret": "your-super-secret-key-at-least-32-characters",
    "Issuer": "FormUpAPI",
    "Audience": "FormUpClient",
    "ExpiryMinutes": 60
  },
  "Storage": {
    "Provider": "Local",
    "BasePath": "uploads/"
  },
  "Cors": {
    "AllowedOrigins": ["http://localhost:3000", "https://formup.app"]
  }
}
```

**4. Setup database**

```bash
dotnet ef database update
```

**5. Jalankan aplikasi**

```bash
dotnet run
```

API akan bisa diakses di `http://localhost:5000`.

## Dokumentasi API

Dokumentasi lengkap API tersedia di file-file berikut:

- **[API Endpoints](./API-ENDPOINTS.md)** - Daftar semua endpoint dengan request dan response
- **[Autentikasi](./API-AUTHENTICATION.md)** - Cara login, register, dan manajemen token
- **[Data Models](./DATA-MODELS.md)** - Struktur data dan database schema
- **[Status Codes](./API-STATUS-CODES.md)** - Penjelasan HTTP status codes
- **[Deployment](./DEPLOYMENT.md)** - Setup production dan monitoring
- **[Requirements](./REQUIREMENTS.md)** - Spesifikasi lengkap project

## Quick Start API

### Base URL

```
https://localhost:5000/api
```

### Autentikasi

Semua request (kecuali register dan login) butuh token JWT di header:

```
Authorization: Bearer <your-jwt-token>
```

### Contoh: Buat Form Baru

```bash
curl -X POST https://localhost:5000/api/forms \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Survey Kepuasan",
    "description": "Tolong isi survey ini",
    "status": "draft"
  }'
```

### Tipe Pertanyaan yang Didukung

| ID | Tipe | Keterangan |
|----|----|-----------|
| 1 | multiple_choice | Pilih satu dari beberapa opsi |
| 2 | checkbox | Pilih lebih dari satu opsi |
| 3 | text | Input text pendek |
| 4 | textarea | Input text panjang |
| 5 | dropdown | Pilih dari dropdown |
| 6 | rating | Rating bintang (1-5 atau 1-10) |
| 7 | date | Pemilih tanggal |
| 8 | time | Pemilih waktu |
| 9 | file_upload | Upload file |
| 10 | linear_scale | Skala linier |

## Development

### Menjalankan Test

```bash
dotnet test
```

### Build untuk Production

```bash
dotnet publish -c Release -o ./publish
```

### Database Migrations

```bash
# Tambah migration baru
dotnet ef migrations add AddNewFeature

# Update database
dotnet ef database update

# Hapus migration
dotnet ef migrations remove
```

## Performance Target

- API Response Time: < 200ms (p95)
- Concurrent Users: 10,000+
- Uptime SLA: 99.9%
- Database Query Time: < 50ms
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
- Implement dependency injection dengan benar
- Tulis unit test untuk business logic
- Dokumentasi public API dengan XML comments

## Support

- Dokumentasi: https://formup.com/docs
- API Reference: https://formup.com/api/docs
- Email: support@formup.com
- GitHub Issues: https://github.com/yourusername/FormUpAPI/issues

## License

Project ini proprietary dan confidential.

## Roadmap

**Phase 1: MVP (Current)**
- Core form management
- Multiple question types
- Response collection
- Basic analytics
- User authentication

**Phase 2: Enhancement (Q2 2026)**
- Template library
- Conditional logic
- Advanced analytics
- Export capabilities
- Webhook support

**Phase 3: Scale (Q3 2026)**
- Mobile application
- Third-party integrations
- Enterprise features
- Team collaboration

**Phase 4: Monetization (Q4 2026)**
- Premium features
- Subscription plans
- Enterprise licenses
- API rate limits

---

Dibuat dengan 💙 oleh FormUp Team