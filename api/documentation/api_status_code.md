# API Status Codes & Rate Limiting FormUp

## Format Response

Semua response menggunakan wrapper `ApiResponse<T>`:

```json
{
  "status": 200,
  "message": "...",
  "data": { ... }
}
```

- `data` berisi payload (bisa `null`, objek, atau array) — bentuknya tergantung endpoint.
- Beberapa endpoint file (QR code, export CSV, download template) mengembalikan file langsung, bukan JSON.
- Error dari middleware (`ErrorHandlingMiddleware`) juga memakai wrapper yang sama.

## HTTP Status Codes yang Dipakai

| Status | Kapan dipakai | Contoh `message` |
|--------|---------------|------------------|
| 200 | Sukses query/update | `OK`, `Form updated` |
| 201 | Resource baru dibuat | `User registered successfully`, `3 questions created` |
| 400 | Validasi gagal / request salah | `Invalid or expired OTP`, `No file uploaded`, `Soal tidak dapat diubah karena form sudah memiliki respons` |
| 401 | Tidak login / token invalid-expired / guest ditolak | `User not found`, `Login required to access this form` |
| 403 | Akses dilarang / form belum buka / sudah tutup | `Form belum dibuka`, `Form sudah ditutup` |
| 404 | Resource tidak ada / soft-deleted / takedown | `Form not found`, `Form tidak ditemukan` |
| 409 | Konflik data (mis. `formLink` sudah dipakai) | `Conflict` |
| 429 | Melebihi rate limit | `Too many requests` |
| 500 | Kesalahan tak terduga di server | `Terjadi kesalahan pada layanan. Silakan coba lagi nanti.` |
| 503 | Database tidak dapat dijangkau | `Layanan sedang tidak tersedia. Silakan coba lagi nanti.` |

Catatan:
- Token JWT kedaluwarsa → `401` + header **`Token-Expired: true`**; client wajib panggil `POST /api/auth/refresh` lalu ulangi request.
- Pesan gate form publik sengaja dibedakan: form tidak ada/takedown/tidak published → `404`, sedangkan jadwal (belum buka/sudah tutup) → `403`.

## Rate Limiting

Rate limit per kebijakan (dikonfigurasi di `Program.cs`):

| Policy | Limit | Berlaku untuk |
|--------|-------|---------------|
| `auth` | 10 request/menit per IP | Login, register, forgot/reset password, OTP |
| `creator` | 120 request/menit per IP | Operasi CRUD form/soal/response owner |
| `submit` | 60 request/menit per kombinasi IP + formLink | Submit respons publik |
| `template` | 10 request/menit per IP | Download template import soal (file digenerate on-the-fly) |

Melebihi limit → `429 Too many requests`. Client sebaikya backoff eksponensial dan retry setelah jeda.

## Pola Penanganan di Client

1. Parse body sebagai `ApiResponse<T>`; angka HTTP status juga tersedia di field `status`.
2. `401` + `Token-Expired: true` → refresh token sekali, lalu ulangi request asli.
3. `400/403/404` → tampilkan `message` ke pengguna (pesan sudah user-friendly, Bahasa Indonesia/Inggris).
4. `429` → tunggu sebelum retry; `500/503` → tampilkan pesan layanan tidak tersedia.
