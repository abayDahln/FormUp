# Protection & Handling API (Mobile)

Dokumen ini merangkum cara aplikasi mobile FormUp melindungi dan menangani respons dari API backend.

## Format Respons API

Semua endpoint backend membungkus respons dalam struktur `ApiResponse<T>`:

```json
{
  "status": 200,
  "message": "Login successful",
  "data": { ... }
}
```

Aplikasi mobile selalu membaca `status` dan `message` untuk menentukan keberhasilan dan menampilkan pesan ke pengguna.

## Penanganan Error di Sisi Server

Backend memasang `ErrorHandlingMiddleware` yang menangkap semua exception tak tertangani:

| Kondisi | Status | Pesan |
|---------|--------|-------|
| Database tidak tersedia (`SqlException`) | `503` | `Server sedang offline. Silakan coba lagi nanti.` |
| Exception tak terduga | `500` | `Internal server error` |

Client mobile cukup menampilkan field `message` dari body respons — detail stack trace tidak pernah dibocorkan ke klien. Error 5xx selalu ditampilkan sebagai pesan generik tanpa detail internal.

## Penanganan Error di Sisi Mobile

Pola yang dipakai di service layer (`lib/core/services/`):

1. **Timeout** — setiap request memiliki timeout 15 detik (analytics lebih lama karena agregasi DB); kegagalan jaringan menghasilkan pesan ramah pengguna (`ApiException`), bukan stack trace.
2. **Status code non-2xx** — body tetap berupa `ApiResponse`, sehingga `message` langsung dipakai untuk snackbar/dialog error (`AuthService.errorMessage`).
3. **Token kedaluwarsa (`401`)** — ketika backend membalas `401` dengan header `Token-Expired: true`, client otomatis memanggil `POST /auth/refresh` lalu mengulang request asli dengan token baru. Jika refresh juga gagal, sesi dibersihkan (`logout`) dan callback `onSessionExpired` mengembalikan pengguna ke layar login.
4. **Debounce mutasi** — semua request mutasi (POST/PUT/PATCH/DELETE) di-throttle via `AppDebouncer` (300 ms per endpoint) untuk mencegah spam klik ganda. GET tidak di-throttle karena sudah di-cache.
5. **Rate limiter client** — `AuthService._RateLimiter` membatasi maksimal 5 percobaan/menit per endpoint auth (login, register, OTP, reset password) sebagai lapisan anti-spam di sisi client (penegakan utama tetap di server).

## Penanganan Offline

- **Deteksi koneksi** — `NetworkStatus` melakukan TCP connect nyata ke host:port API (bukan hanya DNS lookup) dan mem-polling ulang setiap 5 detik saat offline.
- **Request saat offline** — langsung ditolak dengan pesan `Kamu sedang offline. Login dan perubahan data tidak tersedia.` tanpa membuang waktu menunggu timeout.
- **Cache & fallback stale** — `ApiCache` menyimpan hasil GET di memory (TTL pendek) dan disk (`SharedPreferences`, hingga 7 hari untuk data non-sensitif). Saat loader gagal (server down) atau offline, cache stale dikembalikan agar data tetap tampil.
- **Data sensitif tidak pernah di-persist ke disk** — kunci cache yang mengandung `responses`, `analytics`, `admin`, atau `users:me` hanya hidup di memory.
- **Pemisahan cache per akun** — kunci cache memakai scope `email|role` sehingga data akun lain tidak ikut terbaca; cache dibersihkan saat login/logout/ganti akun.

## Proteksi Data Lokal

- Token JWT & `expiresAt` disimpan di **`flutter_secure_storage`** (terenkripsi — Android EncryptedSharedPreferences, iOS Keychain `first_unlock`), **bukan** `shared_preferences`. Data profil non-sensitif (nama, email, role) tetap di `shared_preferences` untuk tampilan.
- Ada **migrasi sekali jalan**: token yang tersimpan lama di `shared_preferences` otomatis dipindahkan ke secure storage lalu dihapus dari sana.
- Base URL API diambil dari `.env` (`API_BASE_URL`) melalui `flutter_dotenv`, dengan fallback `--dart-define=API_BASE_URL` lalu default `http://10.0.2.2:5000/api` — endpoint produksi tidak di-hardcode di source.
- Sesuai prinsip, produksi wajib memakai `https` (ada penanda `isApiSecure` di `auth_service.dart`).
- Logout menghapus token dari secure storage + `shared_preferences`, membersihkan cache, dan me-reset flag offline/debounce/rate limiter.

## Auto-Refresh Sesi

- Setelah login/restore/refresh, timer dijadwalkan tepat pada `expiresAt` untuk memanggil `POST /auth/refresh` secara otomatis (hanya saat *remember me* aktif).
- Jika refresh gagal (token sudah melewati masa *clock skew* 7 hari), sesi diakhiri dan user dikembalikan ke login.
- Saat aplikasi dibuka, sesi yang tersimpan diverifikasi via `GET /auth/verify`; kegagalan jaringan **tidak** meng-logout user (token dianggap masih valid).

## Rate Limiting

Endpoint auth (login/register/OTP/refresh) dibatasi maksimal 10 permintaan/menit per IP oleh backend. Saat menerima `429`, aplikasi menampilkan pesan bahwa permintaan terlalu sering dan mengundang pengguna mencoba beberapa saat lagi.
