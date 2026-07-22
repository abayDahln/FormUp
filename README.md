# FormUp

FormUp adalah platform pembuatan dan pengerjaan formulir berbasis cross-platform yang mendukung antarmuka Web dan Mobile. Project ini dirancang untuk memudahkan pembuatan formulir secara dinamis serta pengumpulan data jawaban secara terstruktur.

Status Project: Early Development

## Struktur Project

```
formup/
├── web/            # Aplikasi web (React)
├── mobile/         # Aplikasi mobile (React Native)
├── api/            # Backend / API service (ASP.NET Core)
└── README.md       
```


## Tech Stack

### Frontend & Mobile
* Web: React
* Mobile: React Native

### Backend & Database
* REST API: ASP.NET Core
* Database: SQL Server

## Fitur Utama

### Form Builder
* Editor formulir dinamis dengan sistem Drag and Drop.
* Penyesuaian tipe input dan struktur pertanyaan secara fleksibel.

### Form Filler & Pengerjaan
* Akses pengerjaan formulir secara online melalui aplikasi Web dan Mobile.
* Dukungan konfigurasi batas waktu pengerjaan (opsional per formulir).

### Analitik & Manajemen Data
* Dashboard hasil respons dan agregasi data jawaban.
* Visualisasi grafik untuk analisis data ringkas.
* Fitur ekspor data respons ke format CSV dan Excel.

## Arsitektur & Alur Kerja

FormUp menggunakan pendekatan monorepo yang memisahkan aplikasi utama dan modul bersama:
1. React (Web) dan React Native (Mobile) berkomunikasi dengan REST API ASP.NET Core.
2. Form builder menghasilkan skema JSON yang disimpan di SQL Server.
3. Saat formulir diisi, validasi data dan kontrol batas waktu ditangani oleh server ASP.NET Core sebelum disimpan ke database.
4. Data respons diolah oleh modul analitik di backend untuk disajikan dalam bentuk grafik dan file ekspor.

## Lisensi

Project ini dilisensikan di bawah MIT License.

## Pengembang

- Abby
- Agustin
- Bella
- Isnan
- Karlo
- Raisyah