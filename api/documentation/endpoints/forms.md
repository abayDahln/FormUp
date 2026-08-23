# Form Endpoints (Sudah Diimplementasikan)


## 1. Buat Form

`POST /api/forms`

**Headers:** `Authorization: Bearer <token>`

**Request:** `description` bisa plain text atau Delta JSON (Quill) untuk teks berformat (bold/italic/warna/alignment, dsb). `descriptionFormat` bersifat opsional — API mendeteksi otomatis (`delta`/`text`); bila diisi akan dipakai.
```json
{
  "title": "Survey Kepuasan",
  "description": "Form survey untuk mengukur kepuasan pelanggan",
  "descriptionFormat": "text"
}
```

**Response 201:**
```json
{
  "status": 201,
  "message": "Form created",
  "data": {
    "id": 1,
    "title": "Survey Kepuasan",
    "description": "Form survey untuk mengukur kepuasan pelanggan",
    "descriptionFormat": "text",
    "bannerImage": null,
    "formLink": "abc123def",
    "status": "draft",
    "responseCount": 0,
    "createdAt": "2026-07-28T10:30:00Z",
    "updatedAt": "2026-07-28T10:30:00Z"
  }
}
```

**Contoh deskripsi berformat (Delta JSON):**
```json
{
  "title": "Survey Kepuasan",
  "description": "[{\"insert\":\"Form survey \",\"attributes\":{\"bold\":true}},{\"insert\":\"kepuasan pelanggan\",\"attributes\":{\"color\":\"#C0392B\"}},{\"insert\":\"\\n\"}]"
}
```
`descriptionFormat` pada respons akan bernilai `delta`.

> **Validasi rich text:** jika `description` diawali `[` maka harus berupa Delta JSON yang valid, jika tidak API menolak dengan `400`.

---

## 2. Daftar Form (Milik Sendiri)

`GET /api/forms`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [ { ... } ]
}
```

---

## 3. Detail Form

`GET /api/forms/{id}`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "id": 1,
    "title": "Survey Kepuasan",
    "description": "...",
    "descriptionFormat": "text",
    "bannerImage": null,
    "formLink": "abc123def",
    "status": "draft",
    "responseCount": 0,
    "settings": {
      "formTypeId": 1,
      "showScore": null,
      "randomizeQuestions": null,
      "timerDuration": null,
      "oneResponse": null,
      "requiredLogin": null,
      "openFormTime": null,
      "closeFormTime": null
    },
    "createdAt": "...",
    "updatedAt": "..."
  }
}
```

---

## 4. Update Form

`PUT /api/forms/{id}`

**Headers:** `Authorization: Bearer <token>`

**Request:** (semua field opsional)
```json
{
  "title": "Judul Baru",
  "description": "Deskripsi baru",
  "descriptionFormat": "text",
  "formLink": "survey-kepuasan-mahasiswa-2024"
}
```
`descriptionFormat` opsional (dideteksi otomatis dari isi bila tidak dikirim). `description` yang diawali `[` harus berupa Delta JSON valid, jika tidak → `400`.

**Response 200:**
```json
{
  "status": 200,
  "message": "Form updated",
  "data": { ... }
}
```

**`formLink` (opsional):** user bisa mengedit sendiri link `/f/{code}`.
- Otomatis di-normalisasi: trim, huruf kecil, spasi → strip (`-`).
- Valid: hanya huruf kecil, angka, dan `-` di antara kata (contoh `survey-kepuasan-2024`). Minimal 3 karakter, maksimal 100.
- Unik global — jika sudah dipakai form lain (termasuk form soft-deleted) → `409 Conflict`.

---

## 5. Hapus Form (Soft Delete)

`DELETE /api/forms/{id}`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "Form deleted"
}
```

---

## 6. Upload Banner Form

`POST /api/forms/{id}/banner`

**Headers:** `Authorization: Bearer <token>`

**Content-Type:** `multipart/form-data`

**Request:** kirim file dengan key `file`

| Aturan | Nilai |
|--------|-------|
| Format | JPG, PNG, GIF, WebP |
| Max size | 10 MB |
| Lokasi | `wwwroot/banner/{guid}.ext` |
| Old file | otomatis dihapus jika update ulang |

**Response 200:**
```json
{
  "status": 200,
  "message": "Banner uploaded",
  "data": {
    "bannerImage": "/banner/550e8400-e29b-41d4-a716-446655440000.jpg"
  }
}
```

**Contoh cURL:**
```bash
curl -X POST http://localhost:5000/api/forms/1/banner \
  -H "Authorization: Bearer <token>" \
  -F "file=@banner.jpg"
```

---

## 7. Update Settings Form

`PATCH /api/forms/{id}/settings`

**Headers:** `Authorization: Bearer <token>`

**Request:** (semua field opsional — hanya field yang dikirim akan berubah)
```json
{
  "formTypeId": 1,
  "showScore": true,
  "randomizeQuestions": false,
  "formToken": "abc123",
  "timerDuration": 300,
  "oneResponse": true,
  "requiredLogin": false,
  "openFormTime": "2026-12-01T08:00:00Z",
  "closeFormTime": "2026-12-31T23:59:59Z"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "Settings updated",
  "data": {
    "formTypeId": 1,
    "showScore": true,
    "randomizeQuestions": false,
    "timerDuration": 300,
    "oneResponse": true,
    "requiredLogin": false,
    "openFormTime": "2026-12-01T08:00:00Z",
    "closeFormTime": "2026-12-31T23:59:59Z"
  }
}
```

**Notes:**
- Jika `FormSetting` row belum ada, akan auto-create saat pertama kali di-PATCH
- `formToken` bisa di-set ke `null` dengan mengirim `"formToken": null`
- `formTypeId` harus ID `FormType` yang valid (1=Single Page, 2=Multi Page); invalid → `400`. Kolom `form_type_id` di DB **NOT NULL** — jika tidak dikirim, row baru otomatis memakai default `1` (Single Page)
- `requiredLogin = true` → responden wajib login untuk mengerjakan (guest ditolak 401)
- **`openFormTime` hanya bisa di-set sekali** — jika sudah pernah di-set, set kedua → `400 Open form time sudah diatur dan tidak bisa diubah`
- `closeFormTime` **bisa di-update** bebas kapan saja
- Setting hanya bisa diubah oleh pemilik form (diverifikasi via JWT)

---

## 8. Publish / Unpublish Form

`POST /api/forms/{id}/publish`

**Headers:** `Authorization: Bearer <token>`

Toggle status draft ↔ published.

**Response 200:**
```json
{
  "status": 200,
  "message": "Form published"
}
```

---

## 9. Info Share Form

`GET /api/forms/{formId}/share`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "formLink": "abc123def",
    "shareUrl": "http://localhost:5000/f/abc123def",
    "requiresToken": false,
    "hasToken": false,
    "qrCodeUrl": "http://localhost:5000/api/forms/1/share/qr"
  }
}
```

---

## 10. QR Code Form

`GET /api/forms/{formId}/share/qr`

**Headers:** `Authorization: Bearer <token>`

Returns PNG image langsung (Content-Type: `image/png`).

---

