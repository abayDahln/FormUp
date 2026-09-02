# FormUp Mobile

![Flutter](https://img.shields.io/badge/Flutter-3-02569B)
![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2)
![License](https://img.shields.io/badge/License-Proprietary-lightgrey)

Aplikasi mobile **Flutter** untuk platform FormUp — mengelola form, mengisi form publik (dengan timer & auto-submit), melihat respons dan analitik, mengelola profil, serta panel admin.

---

## Daftar Isi

1. [Pengenalan & Fitur](#1-pengenalan--fitur)
2. [Overview & Arsitektur](#2-overview--arsitektur)
3. [Tech Stack & Sumber Daya](#3-tech-stack--sumber-daya)
4. [Instalasi & Cara Menjalankan](#4-instalasi--cara-menjalankan)
5. [Kontribusi & Laporan Masalah](#5-kontribusi--laporan-masalah)
6. [Penutup & Lisensi](#6-penutup--lisensi)

---

## 1. Pengenalan & Fitur

FormUp Mobile adalah aplikasi mobile multi-platform (Android/iOS/desktop/web) untuk pengguna FormUp. Fitur utama:

- **Autentikasi lengkap** — login, register dengan verifikasi OTP email, lupa/reset password, ganti password
- **Form Maker** — buat & edit form beserta soal (essay, pilihan ganda, checkbox, tanggal & waktu, benar/salah), banner, dan pengaturan (timer, shuffle, custom link)
- **Form Runner** — pengisian form publik dengan countdown timer, auto-submit, dan hasil skor
- **Respons & Analitik** — riwayat pengisian, detail jawaban responden, statistik form
- **Berbagi** — share link form dan scan QR code
- **Profil** — edit profil, foto avatar, pengaturan
- **Admin** — kelola user, moderasi form, kelola feedback

---

## 2. Overview & Arsitektur

Aplikasi memakai struktur **feature-first** dengan dependensi deklaratif (`RouterDelegate`/`RouterParser`):

```
mobile/
├── lib/
│   ├── main.dart                    # Entrypoint → restore sesi → MaterialApp.router
│   ├── core/
│   │   ├── cache/                   # ApiCache (memory + disk fallback saat offline)
│   │   ├── models/                  # FormModel, QuestionDraft, dst.
│   │   ├── router/                  # AppRouterDelegate, AppPage, AppRouteParser
│   │   ├── services/                # AuthService, FormService, PublicFormService,
│   │   │                            # UserService, AdminService, NetworkStatus
│   │   ├── theme.dart               # Tema Material 3 (seed 0xFF2A9D8F)
│   │   ├── utils/                   # ActionDebouncer, SearchHistory, FormZoom
│   │   └── widgets/                 # Widget bersama (rich_editor, auth_widgets,
│   │                                # form_card, answer_fields, cached_remote_image, dll.)
│   └── features/                    # Layar & widget per fitur
│       ├── admin/                   # Panel admin (user, moderasi, feedback)
│       ├── auth/                    # login, register, OTP, lupa/reset/ganti password
│       ├── form/                    # Form maker (CRUD form, soal, preview)
│       ├── form_runner/             # Pengisian form publik (timer, auto-submit, hasil)
│       ├── home/                    # Dashboard, QR scanner, respons
│       ├── profile/                 # Profil & edit profil
│       ├── responses/               # Detail respons & responden
│       └── settings/                # Pengaturan aplikasi
├── documentation/                   # Dokumentasi konsumsi API (Bahasa Indonesia)
├── ui_screen/                       # Desain mockup layar (PNG/SVG)
├── test/                            # Widget & unit test
├── .env.example                     # Template konfigurasi API_BASE_URL
└── UPDATE_PLAN.md                   # Rencana update berikutnya
```

### Konsep Pendukung

- **Sesi & keamanan**: token disimpan di `flutter_secure_storage` (terenkripsi), refresh token otomatis saat 401, sesi auto-refresh berdasarkan `expiresAt`, rate limiter & debouncer di sisi client
- **Mode offline**: `NetworkStatus` mendeteksi koneksi (TCP check) dan `ApiCache` menyediakan fallback data stale dengan pesan ramah berbahasa Indonesia
- **Deep link**: `https://formup.my.id/f/{code}` dan `/q/{code}` membuka form langsung di aplikasi (Android App Links, `assetlinks.json` wajib ter-deploy)

---

## 3. Tech Stack & Sumber Daya

### Dependencies Utama

| Package | Fungsi |
|---------|--------|
| `http` | Komunikasi REST API |
| `flutter_dotenv` | Konfigurasi `API_BASE_URL` via `.env` |
| `flutter_secure_storage` | Penyimpanan token sesi (terenkripsi) |
| `shared_preferences` | Preferensi & cache disk non-sensitif |
| `flutter_quill` | Editor rich text (delta JSON) untuk deskripsi & soal |
| `image_picker`, `file_picker` | Upload gambar/file |
| `mobile_scanner` | Scan QR code |
| `audioplayers` | Pemutar audio pada soal |
| `share_plus` | Berbagi link form |
| `flutter_math_fork` | Render rumus matematika |
| `cached_network_image` | Cache gambar remote |
| `custom_refresh_indicator`, `material3_expressive_loading_indicator` | UI pull-to-refresh & loading |

### API & Sumber Daya

- **FormUp API** — base URL diatur via `API_BASE_URL` (lihat bagian 4); dokumentasi endpoint: [`../api/documentation/`](../api/documentation/)
- **Dokumentasi konsumsi API mobile** — [`documentation/`](./documentation/):
  - [API Endpoints](./documentation/api_endpoints.md) — daftar endpoint yang dipakai aplikasi
  - [Autentikasi](./documentation/api_authentication.md) — alur login/register OTP/refresh token
  - [Status Codes](./documentation/api_status_code.md) — format status code API
  - [Konsep](./documentation/concepts.md) — konsep inti platform
  - [Alur Link Form](./documentation/form_link_flow.md) — buka form via link/QR
  - [Protection & Handling API](./documentation/protection_and_handling_api.md) — penanganan error & proteksi token
- **Rencana update** — [`UPDATE_PLAN.md`](./UPDATE_PLAN.md)

---

## 4. Instalasi & Cara Menjalankan

### Prasyarat

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (channel stable, Dart ^3.12)
- Perangkat/emulator Android, iOS simulator, desktop, atau target web
- Backend FormUp API yang berjalan (lihat [`../api/README.md`](../api/README.md))

### Langkah Instalasi

**1. Clone repository** (dari root repo) dan masuk ke folder mobile:

```bash
git clone <url-repo-anda>.git
cd FormUp/mobile
```

**2. Pastikan Flutter siap:**

```bash
flutter doctor
```

**3. Buat file `.env`** di folder `mobile/`:

```bash
cp .env.example .env
```

Isi file `.env`:

```dotenv
# Base URL backend API FormUp
# - Android emulator : http://10.0.2.2:5000/api  (10.0.2.2 = host machine dari emulator)
# - Desktop/web/iOS simulator : http://localhost:5000/api
# - Device fisik     : gunakan IP LAN komputer, mis. http://192.168.1.10:5000/api
API_BASE_URL=http://10.0.2.2:5000/api
```

> Nilai ini juga bisa dioverride saat build/run dengan `--dart-define=API_BASE_URL=...`.
> Jika `.env` tidak ada, aplikasi tetap berjalan dengan fallback `--dart-define` lalu default `http://10.0.2.2:5000/api`.

**4. Ambil dependency:**

```bash
flutter pub get
```

**5. Jalankan aplikasi** (pastikan backend API sudah jalan dulu di `http://localhost:5000`):

```bash
flutter run          # pilih device dari daftar yang muncul
```

Target spesifik:

```bash
flutter run -d chrome            # web
flutter run -d windows           # Windows desktop
flutter emulators                # lihat emulator tersedia
flutter run -d emulator-5554     # Android emulator
```

### Build untuk Produksi

```bash
flutter build apk --release         # Android APK
flutter build appbundle             # Android App Bundle (Play Store)
flutter build ipa                   # iOS (butuh macOS + Xcode)
```

### Catatan Android

- Permission `INTERNET`, `CAMERA` (QR scanner), dan `android:usesCleartextTraffic="true"` sudah diatur di `AndroidManifest.xml` karena backend default memakai HTTP biasa (bukan HTTPS).
- Jika device fisik tidak bisa terhubung ke API, pastikan komputer dan device berada di jaringan yang sama dan firewall mengizinkan port 5000.

### Perintah Berguna

```bash
flutter analyze      # static analysis (flutter_lints)
flutter test         # jalankan unit/widget test
flutter build apk    # build APK Android
flutter clean        # bersihkan build artifacts
```

### Catatan Penting

- Login dan register menggunakan **email** (bukan username); username hanya untuk tampilan.
- Waktu server memakai zona **Asia/Jakarta**.

---

## 5. Laporan Masalah

### Melaporkan Masalah

Buka **Issue** baru di repository dengan menyertakan:

1. Judul yang jelas dan ringkas
2. Langkah reproduksi (step-by-step)
3. Perilaku yang diharapkan vs yang terjadi
4. Device/emulator, versi OS, dan versi Flutter (`flutter --version`)
5. Screenshot atau log error (jika ada)

---

## 6. Penutup & Lisensi

FormUp Mobile adalah bagian dari monorepo FormUp bersama backend ([`api/`](../api)) dan web frontend ([`web/form-fe/`](../web/form-fe)). UI mengikuti desain mockup di folder `ui_screen/` — mint `0xFFE1F9F4`, teal `0xFF018081`, Material 3.

**Lisensi**: project ini bersifat **proprietary and confidential**. Tidak diizinkan untuk mendistribusikan, menjual, atau menggunakan kode di luar lingkup yang telah disepakati tanpa izin tertulis dari pemilik.

---

Dibuat dengan 💙 oleh FormUp Team
