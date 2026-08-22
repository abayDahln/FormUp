# FormUp Mobile

Aplikasi mobile **Flutter** untuk platform FormUp — mengelola form, mengisi form publik (dengan timer & auto-submit), melihat respons dan analitik, serta mengelola profil.

## Fitur

- **Autentikasi lengkap**: login, register dengan verifikasi OTP email, lupa/reset password, ganti password
- **Form Maker**: buat & edit form beserta soal (essay, pilihan ganda, checkbox, tanggal & waktu, benar/salah), banner, dan pengaturan (timer, shuffle, custom link)
- **Form Runner**: pengisian form publik dengan countdown timer, auto-submit, dan hasil skor
- **Respons & Analitik**: riwayat pengisian, detail jawaban responden, statistik form
- **Berbagi**: share link form dan scan QR code
- **Profil**: edit profil, foto avatar, pengaturan

## Tech Stack

- **Flutter 3 / Dart 3.12+**
- `http` — komunikasi REST API
- `flutter_dotenv` — konfigurasi `API_BASE_URL` via `.env`
- `shared_preferences` — penyimpanan token sesi
- `flutter_quill` — editor rich text (delta JSON) untuk deskripsi & soal
- `image_picker`, `file_picker` — upload gambar/file
- `mobile_scanner` — scan QR code
- `audioplayers` — pemutar audio pada soal
- `share_plus` — berbagi link form
- `flutter_math_fork` — render rumus matematika

## Prasyarat

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (channel stable, Dart ^3.12)
- Perangkat/emulator Android, atau iOS simulator, atau desktop/web target
- Backend FormUp API yang berjalan (lihat [`api/README.md`](../api/README.md))

## Instalasi

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

### Catatan Android

- Permission `INTERNET` dan `android:usesCleartextTraffic="true"` sudah diatur di `AndroidManifest.xml` karena backend default memakai HTTP biasa (bukan HTTPS).
- Jika device fisik tidak bisa terhubung ke API, pastikan komputer dan device berada di jaringan yang sama dan firewall mengizinkan port 5000.

## Struktur Kode

```
mobile/
├── lib/
│   ├── main.dart                    # Entrypoint → MaterialApp → LoginScreen
│   ├── core/
│   │   ├── models/                  # FormModel, QuestionDraft, dst.
│   │   ├── router/                  # AppRouter (navigasi declarative)
│   │   ├── services/                # AuthService, FormService, PublicFormService, UserService
│   │   └── widgets/                 # Widget bersama (auth widgets, rich editor, dll.)
│   └── features/                    # auth, form, form_runner, home,
│                                    # responses, profile, settings
├── documentation/                   # Dokumentasi konsumsi API
├── ui_screen/                       # Desain mockup layar auth (PNG/SVG)
└── test/                            # Widget & unit test
```

## Perintah Berguna

```bash
flutter analyze      # static analysis (flutter_lints)
flutter test         # jalankan unit/widget test
flutter build apk    # build APK Android
flutter clean        # bersihkan build artifacts
```

## Dokumentasi

Dokumentasi konsumsi API dari sisi mobile ada di [`documentation/`](./documentation/):

- **[API Endpoints](./documentation/api_endpoints.md)** — daftar endpoint yang dipakai aplikasi
- **[Autentikasi](./documentation/api_authentication.md)** — alur login/register OTP/refresh token
- **[Status Codes](./documentation/api_status_code.md)** — format status code API
- **[Konsep](./documentation/concepts.md)** — konsep inti platform
- **[Alur Link Form](./documentation/form_link_flow.md)** — buka form via link/QR
- **[Protection & Handling API](./documentation/protection_and_handling_api.md)** — penanganan error & proteksi token

## Catatan

- Login dan register menggunakan **email** (bukan username); username hanya untuk tampilan.
- Waktu server memakai zona **Asia/Jakarta**.

## License

Project ini proprietary dan confidential.
