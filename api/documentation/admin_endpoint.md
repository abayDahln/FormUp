# Admin Endpoint FormUp

Dokumentasi lengkap endpoint khusus **role ADMIN** — pengelolaan user, form, dan feedback/umpan balik. Semua endpoint sudah diimplementasikan (lihat `Controllers/AdminController.cs` dan `Controllers/FeedbacksController.cs`).

## Base URL

```
http://localhost:5000/api
```

> Port bisa berbeda tergantung konfigurasi (dev default `dotnet run` = `5270`). Sesuaikan dengan environment yang dipakai.

## Autentikasi

Semua endpoint admin wajib membawa JWT di header dan user yang login harus ber-role `ADMIN`.

```
Authorization: Bearer <token>
```

**Header tidak ada / token invalid / kedaluwarsa:**
```json
{ "status": 401, "message": "Unauthorized", "data": null }
```

**Role bukan ADMIN:**
```json
{ "status": 403, "message": "Forbidden", "data": null }
```

**Rate limit:** policy `creator` — maksimal 120 request/menit per user.

## Format Response

Semua response memakai wrapper `ApiResponse<T>`:

```json
{
  "status": 200,
  "message": "OK",
  "data": { ... }
}
```

- `status` — kode HTTP
- `message` — pesan (Bahasa Inggris)
- `data` — payload; `null` untuk response sukses tanpa data

## Konvensi Pagination (Endpoint Daftar)

Tiga endpoint daftar (`users`, `forms`, `feedback`) memakai konvensi yang sama:

- **Tanpa** `page` & `pageSize` → respons **backward-compatible**: `data` berupa array berisi **semua** item (perilaku lama).
- **Dengan** `page` & `pageSize` (`pageSize > 0`) → respons berpaginasi:

```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "items": [ ... ],
    "total": 157,
    "page": 2,
    "pageSize": 20
  }
}
```

| Field | Tipe | Keterangan |
|-------|------|-----------|
| `items` | array | Item pada halaman ini |
| `total` | int | Total item setelah filter (bukan total halaman) |
| `page` | int | Nomor halaman yang diminta |
| `pageSize` | int | Jumlah item per halaman |

---

# 1. Endpoint User

## 1.1 Daftar Semua User

`GET /api/admin/users`

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Query Parameters (semua opsional)

| Param | Tipe | Keterangan |
|-------|------|-----------|
| `page` | int | Nomor halaman (mulai 1) |
| `pageSize` | int | Jumlah item per halaman (> 0) |
| `search` | string | Cari sebagian teks pada `fullname`, `email`, atau `username` (case-insensitive, `contains`) |
| `createdFrom` | datetime | User yang dibuat pada/ setelah tanggal ini (filter `created_at`) |
| `createdTo` | datetime | User yang dibuat pada/ sebelum tanggal ini |
| `status` | string | `banned` = `is_active == false`; `active` = `is_active == true`; dikosongkan = semua |
| `sortBy` | string | Lihat tabel di bawah |

**Nilai `sortBy`:**

| Nilai | Urutan |
|-------|--------|
| `created_desc` (default) | Terbaru → terlama (`created_at` desc) |
| `created_asc` | Terlama → terbaru |
| `form_desc` | Pemilik form terbanyak |
| `form_asc` | Pemilik form terdikit |
| `response_desc` | Pengisi form (response) terbanyak |
| `response_asc` | Pengisi form terdikit |

### Contoh Request

```http
GET /api/admin/users?search=john&status=active&sortBy=form_desc&createdFrom=2026-01-01&page=1&pageSize=20
Authorization: Bearer <token>
```

### Response 200 (berpaginasi)

```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "items": [
      {
        "id": 1,
        "fullname": "John Doe",
        "username": "johndoe",
        "email": "john@example.com",
        "role": "USER",
        "isActive": true,
        "formCount": 5,
        "responseCount": 12,
        "createdAt": "2026-07-28T10:30:00Z",
        "deletedAt": null
      }
    ],
    "total": 1,
    "page": 1,
    "pageSize": 20
  }
}
```

**Field item:**

| Field | Tipe | Keterangan |
|-------|------|-----------|
| `id` | int | ID user |
| `fullname` | string | Nama lengkap |
| `username` | string? | Username (bisa null) |
| `email` | string | Email |
| `role` | string | `USER` / `ADMIN` |
| `isActive` | bool? | `true` = aktif, `false` = dibanned / dinonaktifkan |
| `formCount` | int | Jumlah form aktif milik user (tidak terhitung soft-delete) |
| `responseCount` | int | Jumlah response yang pernah dikerjakan user |
| `createdAt` | datetime? | Tanggal join |
| `deletedAt` | datetime? | Tanggal soft-delete (null = masih aktif) |

---

## 1.2 Detail User

`GET /api/admin/users/{id}`

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "id": 1,
    "fullname": "John Doe",
    "username": "johndoe",
    "email": "john@example.com",
    "role": "USER",
    "profileImage": null,
    "birthdate": "1990-01-15",
    "isActive": true,
    "formCount": 5,
    "responseCount": 12,
    "createdAt": "2026-07-28T10:30:00Z",
    "updatedAt": "2026-07-30T10:30:00Z",
    "deletedAt": null
  }
}
```

**Error:**
- `404 User not found` — ID tidak ada.

---

## 1.3 Ban User

`PUT /api/admin/users/{id}/ban`

Menonaktifkan user (`is_active = false`) sehingga tidak bisa login.

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{ "status": 200, "message": "User has been banned", "data": null }
```

**Error:**
- `404 User not found`
- `400 Cannot ban an admin` — tidak bisa ban sesama admin.

---

## 1.4 Aktifkan User

`PUT /api/admin/users/{id}/activate`

Mengaktifkan kembali user yang dibanned (`is_active = true`).

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{ "status": 200, "message": "User has been activated", "data": null }
```

**Error:** `404 User not found`.

---

## 1.5 Hapus User (Soft Delete)

`DELETE /api/admin/users/{id}`

Menandai user sebagai deleted (`deleted_at` diisi) **dan** menonaktifkannya.

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{ "status": 200, "message": "User deleted", "data": null }
```

**Error:**
- `404 User not found`
- `400 Cannot delete an admin`.

---

# 2. Endpoint Form

## 2.1 Daftar Semua Form

`GET /api/admin/forms`

**Headers:** `Authorization: Bearer <token>` (ADMIN)

Menampilkan semua form dari semua user (termasuk form yang sudah dihapus / takedown / masih draft).

### Query Parameters (semua opsional)

| Param | Tipe | Keterangan |
|-------|------|-----------|
| `page` | int | Nomor halaman (mulai 1) |
| `pageSize` | int | Jumlah item per halaman (> 0) |
| `search` | string | Cari sebagian teks pada `title`, `formLink`, atau nama pembuat (`fullname`) |
| `createdFrom` | datetime | Form dibuat pada/ setelah tanggal ini (`created_at`) |
| `createdTo` | datetime | Form dibuat pada/ sebelum tanggal ini |
| `status` | string | Status form persis sesuai referensi, mis. `published`, `draft`, `closed` |
| `minResponses` | int | Form dengan jumlah response ≥ nilai ini |
| `maxResponses` | int | Form dengan jumlah response ≤ nilai ini |
| `sortBy` | string | Lihat tabel di bawah |

**Nilai `sortBy`:**

| Nilai | Urutan |
|-------|--------|
| `created_desc` (default) | Terbaru → terlama |
| `created_asc` | Terlama → terbaru |
| `response_desc` | Jumlah response terbanyak |
| `response_asc` | Jumlah response terdikit |

### Contoh Request

```http
GET /api/admin/forms?search=survey&status=published&minResponses=10&sortBy=response_desc&page=1&pageSize=20
Authorization: Bearer <token>
```

### Response 200 (berpaginasi)

```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "items": [
      {
        "id": 1,
        "title": "Survey Kepuasan",
        "description": "Form survey untuk mengukur kepuasan pelanggan",
        "formLink": "abc123",
        "status": "published",
        "ownerName": "John Doe",
        "ownerEmail": "john@example.com",
        "responseCount": 10,
        "takenDownAt": null,
        "createdAt": "2026-07-28T10:30:00Z",
        "updatedAt": "2026-07-30T10:30:00Z",
        "deletedAt": null
      }
    ],
    "total": 1,
    "page": 1,
    "pageSize": 20
  }
}
```

**Field item:**

| Field | Tipe | Keterangan |
|-------|------|-----------|
| `id` | int | ID form |
| `title` | string | Judul |
| `description` | string? | Deskripsi (plain text atau Delta JSON) |
| `formLink` | string | Link form `/f/{code}` |
| `status` | string | Status form (`draft` / `published` / `closed`); `unknown` jika null |
| `ownerName` | string | Nama pembuat; `""` jika user null |
| `ownerEmail` | string | Email pembuat; `""` jika user null |
| `responseCount` | int | Jumlah response form |
| `takenDownAt` | datetime? | Waktu takedown (null = normal) |
| `createdAt` | datetime? | Tanggal dibuat |
| `updatedAt` | datetime? | Tanggal terakhir diupdate |
| `deletedAt` | datetime? | Tanggal soft-delete (null = aktif) |

---

## 2.2 Detail Form (Admin)

`GET /api/admin/forms/{id}`

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "id": 1,
    "title": "Survey Kepuasan",
    "description": "Form survey untuk mengukur kepuasan pelanggan",
    "bannerImage": null,
    "formLink": "abc123",
    "status": "published",
    "owner": {
      "id": 1,
      "fullname": "John Doe",
      "email": "john@example.com"
    },
    "takenDownAt": null,
    "responseCount": 10,
    "settings": {
      "formTypeId": 1,
      "showScore": true,
      "randomizeQuestions": false,
      "timerDuration": 300,
      "oneResponse": true,
      "closeFormTime": null
    },
    "createdAt": "2026-07-28T10:30:00Z",
    "updatedAt": "2026-07-30T10:30:00Z",
    "deletedAt": null
  }
}
```

**Catatan `settings`:** hanya field `formTypeId`, `showScore`, `randomizeQuestions`, `timerDuration`, `oneResponse`, `closeFormTime` yang dikirim (bukan seluruh `FormSetting`). `settings` = `null` jika form belum punya `FormSetting`.

**Error:** `404 Form not found`.

---

## 2.3 Takedown Form (Admin)

`POST /api/admin/forms/{id}/takedown`

Menandai form sebagai taken down (`taken_down_at` diisi) — form tidak bisa diakses publik.

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{ "status": 200, "message": "Form has been taken down", "data": null }
```

**Error:**
- `404 Form not found`
- `400 Form is already taken down`.

---

## 2.4 Restore Form (Admin)

`POST /api/admin/forms/{id}/restore`

Mengembalikan form yang ditakedown (`taken_down_at = null`).

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{ "status": 200, "message": "Form has been restored", "data": null }
```

**Error:**
- `404 Form not found`
- `400 Form is not taken down`.

---

## 2.5 Hapus Form (Admin)

`DELETE /api/admin/forms/{id}`

Soft delete form (`deleted_at` diisi).

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{ "status": 200, "message": "Form deleted", "data": null }
```

**Error:** `404 Form not found`.

---

# 3. Endpoint Feedback / Umpan Balik

> Berada di `FeedbacksController` (route `api/admin/feedback`).

## 3.1 Daftar Semua Feedback

`GET /api/admin/feedback`

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Query Parameters (semua opsional)

| Param | Tipe | Keterangan |
|-------|------|-----------|
| `page` | int | Nomor halaman (mulai 1) |
| `pageSize` | int | Jumlah item per halaman (> 0) |
| `search` | string | Cari sebagian teks pada nama user (`fullname`), email user, atau isi `description` feedback |
| `formId` | int | Filter feedback milik form tertentu |
| `createdFrom` | datetime | Feedback dibuat pada/ setelah tanggal ini (`created_at`) |
| `createdTo` | datetime | Feedback dibuat pada/ sebelum tanggal ini |

### Contoh Request

```http
GET /api/admin/feedback?search=inappropriate&formId=1&createdFrom=2026-07-01&page=1&pageSize=20
Authorization: Bearer <token>
```

### Response 200 (berpaginasi)

```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "items": [
      {
        "id": 1,
        "formId": 1,
        "formTitle": "Survey Kepuasan",
        "formLink": "abc123",
        "userId": 1,
        "userName": "John Doe",
        "userEmail": "john@example.com",
        "reason": "Inappropriate",
        "description": "Form ini mengandung konten tidak pantas",
        "createdAt": "2026-07-30T10:30:00Z"
      }
    ],
    "total": 1,
    "page": 1,
    "pageSize": 20
  }
}
```

**Field item:**

| Field | Tipe | Keterangan |
|-------|------|-----------|
| `id` | int | ID feedback |
| `formId` | int | ID form yang dilaporkan |
| `formTitle` | string | Judul form; `""` jika form null |
| `formLink` | string | Link form; `""` jika form null |
| `userId` | int | ID user pelapor |
| `userName` | string | Nama pelapor; `""` jika user null |
| `userEmail` | string | Email pelapor; `""` jika user null |
| `reason` | string | Alasan pelaporan |
| `description` | string? | Deskripsi detail (bisa null) |
| `createdAt` | datetime | Waktu submit feedback |

---

## 3.2 Hapus Feedback

`DELETE /api/admin/feedback/{id}`

Menghapus baris feedback dari database (permanen).

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{ "status": 200, "message": "Feedback dismissed", "data": null }
```

**Error:** `404 Feedback not found`.

---

## 3.3 Takedown Form (via Feedback)

`POST /api/admin/feedback/{id}/takedown`

Menandai form yang terkait feedback sebagai taken down (tidak bisa diakses publik). Form yang sudah ditakedown → `400`.

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{ "status": 200, "message": "Form has been taken down", "data": null }
```

**Error:**
- `404 Feedback not found`
- `404 Form not found` (feedback tanpa form)
- `400 Form is already taken down`.

---

## 3.4 Restore Form (via Feedback)

`POST /api/admin/feedback/{id}/restore`

Mengembalikan form yang ditakedown lewat feedback.

**Headers:** `Authorization: Bearer <token>` (ADMIN)

### Response 200

```json
{ "status": 200, "message": "Form has been restored", "data": null }
```

**Error:**
- `404 Feedback not found`
- `404 Form not found`
- `400 Form is not taken down`.

---

# Ringkasan Status Code

| Kode | Kondisi |
|------|---------|
| `200` | Sukses (GET list/detail, PUT, DELETE, POST) |
| `400` | Validasi bisnis gagal (mis. ban admin, takedown ganda) |
| `401` | Token tidak ada / invalid / kedaluwarsa |
| `403` | Bukan role ADMIN |
| `404` | Resource tidak ditemukan |
| `429` | Rate limit terlampaui (120/menit) |

Catatan: endpoint `GET /api/admin/users`, `GET /api/admin/forms`, dan `GET /api/admin/feedback` kembali ke respons array polos bila dipanggil **tanpa** `page`/`pageSize` — mempertahankan kompatibilitas dengan klien lama.
