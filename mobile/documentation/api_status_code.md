# Status Codes dan Response Format

## Format Respons

Semua endpoint backend membungkus respons dalam wrapper `ApiResponse<T>` — **tidak ada** field `timestamp`/`trace_id`:

```json
{
  "status": 200,
  "message": "...",
  "data": { ... }
}
```

- `status` — HTTP status code yang sama dengan status response
- `message` — pesan yang aman ditampilkan langsung ke pengguna
- `data` — payload (boleh `null`)

## HTTP Status Codes

### Success Responses (2xx)

| Code | Keterangan |
|------|-----------|
| 200 | OK — request berhasil |
| 201 | Created — resource berhasil dibuat (register, buat form, submit response, submit feedback) |

**Contoh Success (200 OK):**

```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "fullname": "John Doe",
    "email": "john@example.com"
  }
}
```

**Contoh Created (201 Created):**

```json
{
  "status": 201,
  "message": "Form created",
  "data": {
    "id": 1,
    "title": "Survey Kepuasan",
    "status": "draft",
    "createdAt": "2026-01-15T10:35:00Z"
  }
}
```

### Client Error Responses (4xx)

| Code | Keterangan | Contoh pesan |
|------|-----------|--------------|
| 400 | Request/validasi tidak valid | `Invalid or expired OTP`, `Soal tidak dapat diubah karena form sudah memiliki respons` |
| 401 | Token tidak ada, expired, invalid, atau akses ditolak | `Invalid email or password`, `You have already submitted a response` |
| 403 | Akses dilarang / gate jadwal form | `Form belum dibuka`, `Form sudah ditutup`, `Anda tidak punya akses` |
| 404 | Resource tidak ditemukan / tidak terpublikasi | `Form tidak ditemukan` |
| 409 | Konflik data | `Email sudah terdaftar`, `formLink sudah dipakai` |
| 429 | Rate limit terlampaui | `Too many requests` |

**Contoh Bad Request (400):**

```json
{
  "status": 400,
  "message": "Invalid or expired OTP",
  "data": null
}
```

**Contoh Unauthorized (401):**

```json
{
  "status": 401,
  "message": "Unauthorized",
  "data": null
}
```

> Token kedaluwarsa juga disertai header `Token-Expired: true` — client mobile otomatis memanggil `POST /api/auth/refresh` lalu mengulang request.

**Contoh Too Many Requests (429):**

```json
{
  "status": 429,
  "message": "Too many requests",
  "data": null
}
```

### Server Error Responses (5xx)

| Code | Keterangan |
|------|-----------|
| 500 | Exception tak terduga — `Internal server error` |
| 503 | Database tidak tersedia — `Server sedang offline. Silakan coba lagi nanti.` |

```json
{
  "status": 503,
  "message": "Server sedang offline. Silakan coba lagi nanti.",
  "data": null
}
```

> Pesan 5xx selalu generik — detail exception/stack trace tidak pernah dikirim ke client.

## Rate Limiting per Grup Endpoint

| Policy | Batas |
|--------|-------|
| `auth` | 10 permintaan/menit per IP (endpoint auth) |
| `creator` | 120 permintaan/menit per user (endpoint creator) |
| `submit` | 60 permintaan/menit per kombinasi IP + formLink (submit respons publik) |
| `template` | 10 download/menit per IP (download template impor) |

## Cara Mobile Menangani Error

Pola di service layer (`lib/core/services/auth_service.dart`):

```dart
static Map<String, dynamic> _decode(http.Response response) {
  // ... parse JSON ...
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiException(
      response.statusCode >= 500
          ? 'Terjadi gangguan pada layanan. Silakan coba lagi nanti.' // 5xx generik
          : (serverMsg ?? 'Terjadi kesalahan.'),                      // 4xx pakai message server
    );
  }
  return json;
}
```

Aturan yang dipakai UI:

1. **4xx** — tampilkan `message` dari server (sudah ramah pengguna).
2. **5xx** — tampilkan pesan generik; jangan tampilkan detail error.
3. **Timeout / koneksi gagal** — `Gagal terhubung. Periksa koneksi internet kamu dan coba lagi.`
4. **Offline** — `Kamu sedang offline. Periksa koneksi internet dan coba lagi.` (dari `ApiCache`/`NetworkStatus`).
5. **401 + `Token-Expired: true`** — refresh token otomatis, lalu ulangi request; jika refresh gagal → logout dan kembali ke login.
