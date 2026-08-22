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

Client mobile cukup menampilkan field `message` dari body respons — detail stack trace tidak pernah dibocorkan ke klien.

## Penanganan Error di Sisi Mobile

Pola yang dipakai di service layer (`lib/core/services/`):

1. **Timeout & exception** — setiap panggilan `http` dibungkus `try/catch`; kegagalan jaringan menghasilkan pesan ramah pengguna, bukan stack trace.
2. **Status code non-2xx** — body tetap berupa `ApiResponse`, sehingga `message` langsung dipakai untuk snackbar/dialog error.
3. **Token kedaluwarsa (`401`)** — ketika backend membalas `401 token-expired` (header `Token-Expired: true`), client otomatis memanggil `POST /auth/refresh` lalu mengulang request asli dengan token baru. Jika refresh juga gagal, sesi dibersihkan (`clearSession`) dan pengguna dikembalikan ke layar login.
4. **Debounce** — operasi seperti pull-to-refresh dibatasi interval minimal antar panggilan agar tidak spam ke server.

## Proteksi Data Lokal

- Token JWT disimpan via `shared_preferences` dan dilampirkan pada header `Authorization: Bearer <token>` untuk setiap request terproteksi.
- Base URL API diambil dari `.env` (`API_BASE_URL`) melalui `flutter_dotenv`, sehingga endpoint produksi tidak di-hardcode di source.
- Logout menghapus token dari penyimpanan lokal.

## Rate Limiting

Endpoint auth (login/register/OTP/refresh) dibatasi maksimal 10 permintaan/menit per IP oleh backend. Saat menerima `429`, aplikasi menampilkan pesan bahwa permintaan terlalu sering dan mengundang pengguna mencoba beberapa saat lagi.
