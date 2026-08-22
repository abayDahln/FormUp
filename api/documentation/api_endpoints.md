# API Endpoints FormUp

**Status: Development** — seluruh endpoint auth, user, form, question, response, feedback, admin, analytics, dan **public form** sudah diimplementasikan.

## Base URL

```
http://localhost:5000/api
```

## Response Format

Semua response menggunakan wrapper `ApiResponse<T>`:

```json
{
  "status": 200,
  "message": "...",
  "data": { ... }
}
```

---

# Auth Endpoints (Sudah Diimplementasikan)

## 1. Register (Kirim OTP)

`POST /api/auth/register`

Kirim OTP verifikasi ke email. User **belum dibuat** di tahap ini.

**Request:**
```json
{
  "fullname": "John Doe",
  "email": "john@example.com",
  "password": "SecurePass123!"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "OTP has been sent to your email",
  "data": null
}
```

**Validasi:** email belum terdaftar, format field benar. `username` dan `birthdate` **opsional** — bisa diisi nanti lewat `PUT /api/users/me`.

---

## 2. Verify Registration (Selesaikan Register)

`POST /api/auth/verify-registration`

Verifikasi OTP lalu buat user. Body sama seperti register + field `otp`.

**Request:**
```json
{
  "fullname": "John Doe",
  "email": "john@example.com",
  "password": "SecurePass123!",
  "otp": "123456"
}
```

**Response 201:**
```json
{
  "status": 201,
  "message": "User registered successfully",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": 1,
      "fullname": "John Doe",
      "username": "johndoe",
      "email": "john@example.com",
      "role": "USER",
      "profileImage": null,
      "isActive": true,
      "createdAt": "2026-01-15T10:30:00Z"
    },
    "expiresAt": "2026-01-22T10:30:00Z"
  }
}
```

**Validasi:**
- OTP berlaku 15 menit
- Jika OTP salah/kedaluwarsa → `400 Invalid or expired OTP`
- OTP sekali pakai (langsung invalid setelah dipakai)
- Panggil `register` lagi untuk kirim ulang OTP baru (OTP lama otomatis dibatalkan)

---

## 3. Login

`POST /api/auth/login`

**Request:**
```json
{
  "email": "john@example.com",
  "password": "SecurePass123!"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "Login successful",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": { ... },
    "expiresAt": "2026-01-22T10:30:00Z"
  }
}
```

---

## 4. Refresh Token

`POST /api/auth/refresh`

**Headers:** `Authorization: Bearer <token>` (tanpa body)

**Response 200:**
```json
{
  "status": 200,
  "message": "Token refreshed",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_at": "2026-01-22T12:30:00Z"
  }
}
```

---

## 5. Lupa Password

`POST /api/auth/forgot-password`

**Request:**
```json
{
  "email": "john@example.com"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "OTP has been sent to your email",
  "data": null
}
```

---

## 6. Reset Password

`POST /api/auth/reset-password`

**Request:**
```json
{
  "email": "john@example.com",
  "otp": "123456",
  "newPassword": "NewSecurePass456!"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "Password has been reset successfully",
  "data": null
}
```

---

---

# User Profile Endpoints (Sudah Diimplementasikan)

## 1. Lihat Profile

`GET /api/users/me`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
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
    "createdAt": "2026-01-15T10:30:00Z",
    "updatedAt": "2026-01-22T10:30:00Z"
  }
}
```

---

## 2. Update Profile

`PUT /api/users/me`

**Headers:** `Authorization: Bearer <token>`

**Request:** (semua field opsional — hanya field yang diisi akan diubah)
```json
{
  "fullname": "Johnathan Doe",
  "username": "johnathan_doe",
  "birthdate": "1990-06-15",
  "profileImage": "https://formup.com/uploads/avatar.jpg"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "Profile updated",
  "data": { ... }
}
```

---

## 3. Ganti Password

`POST /api/users/change-password`

**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "currentPassword": "SecurePass123!",
  "newPassword": "NewSecurePass456!"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "Password changed successfully",
  "data": null
}
```

---

## 4. Upload Profile Image

`POST /api/users/me/profile-image`

**Headers:** `Authorization: Bearer <token>`

**Content-Type:** `multipart/form-data`

**Request:** kirim file dengan key `file`

| Aturan | Nilai |
|--------|-------|
| Format | JPG, PNG, GIF, WebP |
| Max size | 10 MB |
| Lokasi | `wwwroot/profile/{guid}.ext` |
| Old file | otomatis dihapus jika update ulang |

**Response 200:**
```json
{
  "status": 200,
  "message": "Profile image uploaded",
  "data": {
    "profileImage": "/profile/550e8400-e29b-41d4-a716-446655440000.jpg"
  }
}
```

**Contoh cURL:**
```bash
curl -X POST http://localhost:5000/api/users/me/profile-image \
  -H "Authorization: Bearer <token>" \
  -F "file=@avatar.jpg"
```

---

## 5. My Stats

`GET /api/users/me/stats`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "totalForms": 5,
    "totalResponses": 12,
    "totalFeedbackGiven": 2
  }
}
```

- `totalForms` = jumlah form yang dibuat user
- `totalResponses` = jumlah response yang masuk ke semua form milik user
- `totalFeedbackGiven` = jumlah feedback yang pernah user kirim

---

## 6. My Responses (Form yang Pernah Dikerjakan)

`GET /api/users/me/responses`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "responseId": 1,
      "formId": 2,
      "formTitle": "Survey Kepuasan",
      "formLink": "abc123",
      "status": "new",
      "submittedAt": "2026-07-30T10:30:00Z"
    }
  ]
}
```

Menampilkan semua form yang pernah dikerjakan oleh user, diurutkan dari terbaru.

Untuk melihat **hasil** (nilai, benar/salah) dari salah satu item, panggil endpoint hasil publik `GET /api/public/forms/{formLink}/responses/{responseId}` sambil membawa JWT pemilik respons (lihat bagian Public Form Endpoints §4).

---

# Reference Endpoints (Sudah Diimplementasikan)

Butuh JWT. Dipakai builder form untuk mengisi dropdown tipe/status.

## 1. Form Types

`GET /api/references/form-types`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    { "id": 1, "type": "Single Page" },
    { "id": 2, "type": "Multi Page" }
  ]
}
```

## 2. Form Statuses

`GET /api/references/form-statuses`

```json
{
  "status": 200,
  "message": "OK",
  "data": [
    { "id": 1, "status": "Draft" },
    { "id": 2, "status": "Published" },
    { "id": 3, "status": "Closed" }
  ]
}
```

## 3. Question Types

`GET /api/references/question-types`

```json
{
  "status": 200,
  "message": "OK",
  "data": [
    { "id": 1, "type": "Essay" },
    { "id": 2, "type": "Multiple Choice" },
    { "id": 3, "type": "Checkbox" },
    { "id": 4, "type": "Date Time" },
    { "id": 5, "type": "True False" }
  ]
}
```

---

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

# Public Form Endpoints (Responden, Tanpa Login)

Endpoint ini dipakai responden untuk mengerjakan form lewat link `/f/{code}` (web: route `/f/:code`, mobile: deep link). **Tidak butuh JWT** (kecuali form `requiresLogin`).

Alur 2-langkah agar **soal aman**: GET info+requirement dulu, baru POST `/questions` untuk ambil soal.

## 1. Ambil Info + Requirement Form Publik

`GET /api/public/forms/{formLink}`

Balas meta + requirement form, **tanpa soal**.

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
    "requiresToken": false,
    "requiresLogin": false,
    "showScore": true,
    "timerDuration": 300,
    "randomizeQuestions": false,
    "openFormTime": null,
    "closeFormTime": null
  }
}
```

**Gate — pesan dibedakan:**

| Kondisi | HTTP | Message |
|---------|------|---------|
| `formLink` tidak ada / soft-delete / takedown / status bukan `published` | 404 | `Form tidak ditemukan` |
| `openFormTime` belum lewat | 403 | `Form belum dibuka` (data berisi `openFormTime`) |
| `closeFormTime` sudah lewat | 403 | `Form sudah ditutup` (data berisi `closeFormTime`) |

## 2. Ambil Soal Publik

`POST /api/public/forms/{formLink}/questions`

Kirim JSON `{ token?, name? }`:
- `token` — wajib jika `requiresToken` true (token form).
- `name` — nama tamu (opsional, jika form tidak `requiresLogin`).

**Request:**
```json
{ "token": "abc123", "name": "Budi" }
```

**Validasi sebelum soal dikirim:**
- `requiresLogin = true` dan tidak bawa JWT → `401 Login required to access this form`
- Form ber-`FormToken` dan `token` salah/kosong → `401 Invalid or missing form token`
- Gate 404/403 open/closed sama seperti GET di atas

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "formId": 1,
    "questions": [
      {
        "id": 1,
        "typeId": 2,
        "question": "Apa warna langit?",
        "questionFormat": "text",
        "questionOrder": 1,
        "isRequired": true,
        "correctAnswer": null,
        "randomizeOptions": false,
        "options": [
          { "id": 1, "optionText": "Biru", "optionImage": null, "isCorrect": null, "optionOrder": 1 }
        ]
      }
    ]
  }
}
```

**Catatan anti-bocor:** `correctAnswer` dan `isCorrect` selalu `null`. `responseCount` tidak pernah dikirim.

## 3. Submit Response (Publik via Link)

`POST /api/public/forms/{formLink}/responses`

Sama persis seperti `POST /api/forms/{formId}/responses` (lihat Response Endpoints), tapi menerima `formLink`.

**Request:**
```json
{
  "token": "abc123",
  "respondentName": "Budi",
  "guestToken": "kode-unik-persisten-dari-client",
  "answers": [
    { "questionId": 1, "optionId": 2 },
    { "questionId": 2, "answerValue": "Jawaban text" }
  ]
}
```

**Response 201:**
```json
{
  "status": 201,
  "message": "Response submitted",
  "data": { "responseId": 1, "guestToken": "..." }
}
```

- `guestToken` di-generate server (GUID) jika klien tidak mengirim; **disimpan & dikembalikan** supaya klien bisa ambil hasil.
- `guestToken` `null` untuk user login.
- `oneResponse = true`: user login dicek via `respondentId`; **guest dicek via `guestToken`** yang sama → submit kedua ditolak `400 You have already submitted a response`.

**Rate limit:** policy `submit` — 60/menit per kombinasi IP + `formLink`.

## 4. Lihat Hasil (Responden)

`GET /api/public/forms/{formLink}/responses/{responseId}?token=<guestToken>`

Akses:
- **Guest:** wajib `?token=` berisi `guestToken` yang cocok (token salah → `401`).
- **User login:** bawa JWT, hanya pemilik respons (`respondent_id`) yang boleh (`401` untuk user lain).

**Response 200 (jika `showScore = true`):**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "responseId": 1,
    "formId": 1,
    "formTitle": "Survey Kepuasan",
    "showScore": true,
    "score": 100.0,
    "correctCount": 2,
    "wrongCount": 0,
    "totalQuestions": 2,
    "scorableQuestions": 2,
    "answeredCount": 2,
    "answers": [
      {
        "questionId": 1,
        "question": "2+2 berapa?",
        "questionFormat": "text",
        "typeId": 1,
        "answerText": "4",
        "correctAnswer": "4",
        "isCorrect": true
      }
    ]
  }
}
```

**Jika `showScore = false`:** `score`, `correctCount`, `wrongCount` = 0/null dan per soal `correctAnswer`/`isCorrect` tidak dikirim (hanya jawaban responden).

## 5. Riwayat Attempt Saya pada Satu Form (User Login)

`GET /api/public/forms/{formLink}/my-responses`

**Headers:** `Authorization: Bearer <token>`

Mengembalikan semua attempt user yang sedang login untuk form ini, terbaru lebih dulu — dipakai tab Riwayat (pengelompokan per form) dan pemilih attempt.

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "responseId": 12,
      "submittedAt": "2026-08-22T09:15:00Z",
      "showScore": true,
      "score": 87.5,
      "correctCount": 7,
      "wrongCount": 1
    }
  ]
}
```

Catatan: `showScore`, `score`, `correctCount`, `wrongCount` mengikuti pengaturan form; `score` `null` jika form tidak menampilkan nilai. Tidak mensyaratkan form masih `published` — riwayat tetap bisa dibuka walau form sudah di-unpublish.

---

# Question Endpoints (Sudah Diimplementasikan)

> **Aturan mutasi soal:** soal boleh diedit selama form belum punya respons apa pun — termasuk form berstatus `published`. Jika sudah ada minimal 1 respon, semua mutasi soal ditolak `400 Soal tidak dapat diubah karena form sudah memiliki respons` (menjaga konsistensi data jawaban). Form `published` yang kehabisan soal otomatis kembali ke status `draft`.

## 1. Daftar Pertanyaan

`GET /api/forms/{formId}/questions`

**Headers:** `Authorization: Bearer <token>`

Diakses oleh **pemilik form** atau **admin** (role `ADMIN`).

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "id": 1,
      "formId": 1,
      "typeId": 1,
      "question": "Apa pendapat Anda?",
      "questionFormat": "text",
      "questionOrder": 1,
      "isRequired": true,
      "options": [
        { "id": 1, "optionText": "Sangat Puas", "isCorrect": false, "optionOrder": 1 }
      ],
      "createdAt": "...",
      "updatedAt": "..."
    }
  ]
}
```

---

## 2. Simpan Questions

`POST /api/forms/{formId}/questions`

**Headers:** `Authorization: Bearer <token>`

Buat soal + opsi sekaligus dalam 1 request.

**Request:** `question` bisa plain text atau Delta JSON (Quill) untuk teks berformat. `questionFormat` opsional (dideteksi otomatis dari isi). Soal yang diawali `[` harus Delta JSON valid, jika tidak → `400`.
```json
{
  "questions": [
    {
      "typeId": 1,
      "question": "Apa warna langit?",
      "isRequired": true,
      "options": [
        { "optionText": "Biru", "isCorrect": true },
        { "optionText": "Hijau", "isCorrect": false }
      ]
    },
    {
      "typeId": 3,
      "question": "2+2 berapa?",
      "isRequired": true,
      "correctAnswer": "4"
    }
  ]
}
```

**Contoh pertanyaan berformat (Delta JSON):**
```json
{
  "typeId": 1,
  "question": "[{\"insert\":\"Apa warna \",\"attributes\":{\"italic\":true}},{\"insert\":\"langit\",\"attributes\":{\"bold\":true}},{\"insert\":\"?\\n\"}]",
  "isRequired": true
}
```
Pada respons, `questionFormat` akan bernilai `delta`.

**Response 201:** Array questions dengan ID masing-masing.

---

## 3. Simpan / Update Questions

`PUT /api/forms/{formId}/questions`

**Headers:** `Authorization: Bearer <token>`

Update soal **in-place** (bukan replace-all lagi). Setiap item boleh membawa `id`:
- Item dengan `id` yang cocok dengan soal aktif → soal **di-update** (teks, tipe, order, opsi, dsb).
- Item tanpa `id` → soal **baru** dibuat.
- Soal aktif yang **tidak ada** di payload → di-soft-delete.

Opsi selalu diganti utuh per soal (hapus lama, buat ulang dari `options`).

**Request:** `questionFormat` opsional (dideteksi otomatis dari isi); `question` diawali `[` harus Delta JSON valid, jika tidak → `400`.
```json
{
  "questions": [
    {
      "id": 1,
      "typeId": 1,
      "question": "Apa warna langit? (diubah)",
      "questionFormat": "text",
      "isRequired": true,
      "options": [
        { "optionText": "Biru", "isCorrect": true },
        { "optionText": "Ungu", "isCorrect": false }
      ]
    },
    {
      "typeId": 3,
      "question": "2+2 berapa? (soal baru)",
      "isRequired": true,
      "correctAnswer": "4"
    }
  ]
}
```

**Response 200:** Array questions aktif setelah save (dengan ID masing-masing).

**Catatan:** Karena update in-place, `questionId` pada response lama tetap valid — analitik & export tidak kehilangan history saat soal diedit.

---

## 4. Hapus Pertanyaan

`DELETE /api/forms/{formId}/questions/{id}`

**Headers:** `Authorization: Bearer <token>`

Soft delete satu pertanyaan beserta opsi-nya. Hanya pemilik form.

**Response 200:**
```json
{
  "status": 200,
  "message": "Question deleted"
}
```

---

## 5. Upload Image Question

`POST /api/forms/{formId}/questions/{id}/upload-image`

**Headers:** `Authorization: Bearer <token>`

**Content-Type:** `multipart/form-data` — kirim file dengan key `file`

Upload & langsung set `questionImage` ke question ID tersebut. File lama otomatis dihapus.

| Aturan | Nilai |
|--------|-------|
| Format | JPG, PNG, GIF, WebP |
| Max size | 10 MB |
| Lokasi | `wwwroot/questions/images/{guid}.ext` |

**Response 200:**
```json
{
  "status": 200,
  "message": "Image uploaded",
  "data": { "questionImage": "/questions/images/xxx.jpg" }
}
```

---

## 6. Upload Audio Question

`POST /api/forms/{formId}/questions/{id}/upload-audio`

**Headers:** `Authorization: Bearer <token>`

**Content-Type:** `multipart/form-data` — kirim file dengan key `file`

Upload audio untuk soal. File lama otomatis dihapus.

| Aturan | Nilai |
|--------|-------|
| Format | MP3, WAV, OGG, M4A, AAC, WebM |
| Max size | 20 MB |
| Lokasi | `wwwroot/questions/audio/{guid}.ext` |

**Response 200:**
```json
{
  "status": 200,
  "message": "Audio uploaded",
  "data": { "questionAudio": "/questions/audio/xxx.mp3" }
}
```

---

## 7. Import Soal dari File

`POST /api/forms/{formId}/questions/import`

**Headers:** `Authorization: Bearer <token>`

**Content-Type:** `multipart/form-data`

Kirim file dengan key `file`.

| Aturan | Nilai |
|--------|-------|
| Format | `.xlsx`, `.xls`, `.csv`, `.pdf`, `.docx` |
| Max size | 5 MB |

**Format CSV / Excel (baris pertama = header):**

| Header | Required | Default | Keterangan |
|--------|----------|---------|-----------|
| `question` | Ya | — | Teks pertanyaan |
| `type_id` | Tidak | 1 | ID tipe pertanyaan (lihat tabel QuestionType) |
| `order` | Tidak | auto | Urutan pertanyaan |
| `is_required` | Tidak | FALSE | `TRUE` / `FALSE` |
| `randomize_options` | Tidak | FALSE | `TRUE` / `FALSE` |
| `correct_answer` | Tidak | — | Jawaban benar (untuk quiz) |
| `options` | Tidak | — | Opsi dipisah pipe: `Opsi A\|Opsi B\|Opsi C` |

**Contoh isi CSV:**
```csv
question,type_id,order,is_required,options
Apa warna langit?,1,1,TRUE,Biru|Hijau|Merah
2+2 berapa?,3,2,TRUE,
```

**Format PDF / DOCX:**

Setiap soal dipisah oleh baris kosong. Format metadata:

```
Question: Apa warna langit?
Options: Biru | Hijau | Merah
Type ID: 1
Is Required: true
```

Atau opsi bisa ditulis per baris dengan awalan `- `:
```
Apa warna langit?
- Biru
- Hijau
- Merah
type_id: 1
```

**Template download:** `GET /api/templates/import-questions?format=csv` (lihat bagian Template Endpoints)

**Response 200:**
```json
{
  "status": 200,
  "message": "3 questions imported",
  "data": {
    "totalImported": 3,
    "totalSkipped": 0,
    "errors": []
  }
}
```

---

# Response Endpoints (Sudah Diimplementasikan)

## 1. Submit Response (Publik)

`POST /api/forms/{formId}/responses`

**Headers:** (opsional) `Authorization: Bearer <token>` untuk user login, <br>
**Token:** kirim `token` di body jika form memerlukan token akses.

**Request:**
```json
{
  "token": null,
  "respondentName": "Budi",
  "guestToken": "kode-unik-persisten-dari-client",
  "answers": [
    { "questionId": 1, "optionId": 2 },
    { "questionId": 2, "answerValue": "Jawaban text" },
    { "questionId": 3, "optionId": null, "answerValue": "Bebas" }
  ]
}
```

Untuk pilihan ganda: kirim `optionId`. Untuk text: kirim `answerValue`.

**Validasi:**
- Form harus berstatus `published`
- Jika `openFormTime` belum lewat → `403 Form belum dibuka`
- Jika `closeFormTime` sudah lewat → `403 Form sudah ditutup`
- Jika `requiresLogin = true` → wajib bawa JWT (tanpa login → `401`)
- Jika form memerlukan token → body wajib menyertakan `token` yang sesuai
- Jika `oneResponse = true` dan sudah pernah submit → ditolak `400`. User login dicek via `respondent_id`; **guest dicek via `guestToken`** yang sama
- `questionId` harus milik form tersebut

**Response 201:**
```json
{
  "status": 201,
  "message": "Response submitted",
  "data": { "responseId": 1, "guestToken": null }
}
```

- `guestToken` diisi GUID (server generate) jika submit sebagai guest tanpa mengirim; `null` untuk user login. Simpan di client (mis. localStorage) untuk ambil hasil & cek one-response.

---

## 2. Daftar Responses (Owner)

`GET /api/forms/{formId}/responses?page=1&pageSize=20`

**Headers:** `Authorization: Bearer <token>`

Mendukung pagination: kirim `page` + `pageSize` → respons `{items, total, page, pageSize}`; tanpa parameter → array penuh (backward-compat).

**Response 200 (dengan pagination):**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "items": [
      {
        "id": 1,
        "respondentName": "John Doe",
        "status": "new",
        "submittedAt": "2026-07-28T10:30:00Z"
      }
    ],
    "total": 42,
    "page": 1,
    "pageSize": 20
  }
}
```

---

## 3. Detail Response (Owner)

`GET /api/forms/{formId}/responses/{id}`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "id": 1,
    "formId": 1,
    "respondentName": "John Doe",
    "status": "new",
    "submittedAt": "2026-07-28T10:30:00Z",
    "answers": [
      {
        "questionId": 1,
        "question": "Apa warna langit?",
        "questionFormat": "text",
        "typeId": 1,
        "optionId": 2,
        "optionText": "Biru",
        "answerValue": null
      },
      {
        "questionId": 2,
        "question": "Komentar",
        "questionFormat": "text",
        "typeId": 4,
        "optionId": null,
        "optionText": null,
        "answerValue": "Bagus"
      }
    ]
  }
}
```

---

## 4. Hasil Lengkap Response (Owner)

`GET /api/forms/{formId}/responses/{id}/result`

**Headers:** `Authorization: Bearer <token>`

Hasil lengkap satu respons milik responden — format identik dengan endpoint hasil publik (`ResponseScorer.BuildResult`): skor, kunci jawaban, opsi tiap soal, dan `selectedOptions` (semua opsi/teks yang dipilih responden; penting untuk checkbox multi-pilihan). Dipakai screen Respondent Detail.

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "responseId": 1,
    "formId": 1,
    "formTitle": "Quiz Matematika",
    "showScore": true,
    "score": 87.5,
    "correctCount": 7,
    "wrongCount": 1,
    "totalQuestions": 8,
    "scorableQuestions": 8,
    "answeredCount": 8,
    "answers": [
      {
        "questionId": 1,
        "question": "2+2 berapa?",
        "questionFormat": "text",
        "typeId": 3,
        "answerText": "4",
        "correctAnswer": "4",
        "isCorrect": true,
        "options": ["3", "4", "5"],
        "selectedOptions": ["4"]
      }
    ]
  }
}
```

---

## 5. Attempt Lain Responden yang Sama (Owner)

`GET /api/forms/{formId}/responses/{id}/attempts`

**Headers:** `Authorization: Bearer <token>`

Daftar semua attempt responden yang sama pada form yang sama — dicocokkan via akun login (`respondent_id`); untuk guest memakai pencocokan nama (`respondent_name`). Diurutkan terbaru lebih dulu.

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "responseId": 12,
      "submittedAt": "2026-08-22T09:15:00Z",
      "showScore": true,
      "score": 87.5,
      "correctCount": 7,
      "wrongCount": 1
    }
  ]
}
```

---

## 6. Update Status Response (Owner)

`PUT /api/responses/{id}/status`

**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "statusId": 2
}
```

Status: 1=new, 2=reviewed, 3=flagged.

> **Catatan UI:** opsi ubah status (accept/reject) sudah dihapus dari aplikasi mobile; endpoint ini masih tersedia untuk kompatibilitas.

**Response 200:**
```json
{
  "status": 200,
  "message": "Status updated"
}
```

---

## 7. Export Responses (Owner)

`GET /api/forms/{formId}/responses/export`

**Headers:** `Authorization: Bearer <token>`

Returns file CSV langsung (Content-Type: `text/csv`).

Kolom: Response ID, Submitted At, Respondent, [jawaban per pertanyaan], Status.

---

# Feedback Endpoints (Sudah Diimplementasikan)

## 1. Submit Feedback (User)

`POST /api/forms/{formId}/feedback`

**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "reason": "Inappropriate",
  "description": "Form ini mengandung konten tidak pantas dan menyesatkan"
}
```

**Validasi:**
- User harus login
- User harus sudah menyelesaikan form (punya response)
- Form harus berstatus `published`
- User belum pernah submit feedback untuk form ini
- `reason` harus diisi (string bebas)

**Response 201:**
```json
{
  "status": 201,
  "message": "Feedback submitted",
  "data": { "feedbackId": 1 }
}
```

---

## 2. Lihat Feedback Saya (User)

`GET /api/forms/{formId}/feedback`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "id": 1,
    "formId": 1,
    "formTitle": "Survey Kepuasan",
    "userId": 1,
    "userName": "John Doe",
    "reason": "Inappropriate",
    "description": "Form ini mengandung konten tidak pantas...",
    "createdAt": "2026-07-30T10:30:00Z"
  }
}
```

---

## 3. Admin: Daftar Semua Feedback

`GET /api/admin/feedback`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "id": 1,
      "formId": 1,
      "formTitle": "Survey Kepuasan",
      "formLink": "abc123",
      "userId": 1,
      "userName": "John Doe",
      "userEmail": "john@example.com",
      "reason": "Inappropriate",
      "description": "Form ini mengandung konten tidak pantas...",
      "createdAt": "2026-07-30T10:30:00Z"
    }
  ]
}
```

---

## 4. Admin: Hapus Feedback

`DELETE /api/admin/feedback/{id}`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Menghapus feedback dari database.

**Response 200:**
```json
{
  "status": 200,
  "message": "Feedback dismissed"
}
```

---

## 5. Admin: Takedown Form

`POST /api/admin/feedback/{id}/takedown`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Menandai form sebagai taken down (form tidak bisa diakses publik).

**Response 200:**
```json
{
  "status": 200,
  "message": "Form has been taken down"
}
```

---

## 6. Admin: Restore Form

`POST /api/admin/feedback/{id}/restore`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Mengembalikan form yang di-takedown.

**Response 200:**
```json
{
  "status": 200,
  "message": "Form has been restored"
}
```

---

# Admin Endpoints (Sudah Diimplementasikan)

Semua endpoint admin membutuhkan role `ADMIN`.

## 1. Daftar Semua User

`GET /api/admin/users`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "id": 1,
      "fullname": "John Doe",
      "username": "johndoe",
      "email": "john@example.com",
      "role": "USER",
      "isActive": true,
      "formCount": 5,
      "createdAt": "2026-07-28T10:30:00Z",
      "deletedAt": null
    }
  ]
}
```

---

## 2. Detail User

`GET /api/admin/users/{id}`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

**Response 200:**
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

---

## 3. Ban User

`PUT /api/admin/users/{id}/ban`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Menonaktifkan user (tidak bisa login). Admin tidak bisa ban admin lain.

**Response 200:**
```json
{
  "status": 200,
  "message": "User has been banned"
}
```

---

## 4. Aktifkan User

`PUT /api/admin/users/{id}/activate`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Mengaktifkan kembali user yang di-ban.

**Response 200:**
```json
{
  "status": 200,
  "message": "User has been activated"
}
```

---

## 5. Hapus User (Soft Delete)

`DELETE /api/admin/users/{id}`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Menandai user sebagai deleted. Admin tidak bisa menghapus admin lain.

**Response 200:**
```json
{
  "status": 200,
  "message": "User deleted"
}
```

---

## 6. Daftar Semua Form

`GET /api/admin/forms`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Menampilkan semua form dari semua user (termasuk yang sudah dihapus).

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "id": 1,
      "title": "Survey Kepuasan",
      "description": "...",
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
  ]
}
```

---

## 7. Detail Form (Admin)

`GET /api/admin/forms/{id}`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

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
    "formLink": "abc123",
    "status": "published",
    "owner": {
      "id": 1,
      "fullname": "John Doe",
      "email": "john@example.com"
    },
    "takenDownAt": null,
    "responseCount": 10,
    "settings": { ... },
    "createdAt": "...",
    "updatedAt": "...",
    "deletedAt": null
  }
}
```

---

## 8. Admin: Takedown Form

`POST /api/admin/forms/{id}/takedown`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Menandai form sebagai taken down (tidak bisa diakses publik).

**Response 200:**
```json
{
  "status": 200,
  "message": "Form has been taken down"
}
```

---

## 9. Admin: Restore Form

`POST /api/admin/forms/{id}/restore`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Mengembalikan form yang di-takedown.

**Response 200:**
```json
{
  "status": 200,
  "message": "Form has been restored"
}
```

---

## 10. Admin: Hapus Form

`DELETE /api/admin/forms/{id}`

**Headers:** `Authorization: Bearer <token>` (role ADMIN)

Soft delete form.

**Response 200:**
```json
{
  "status": 200,
  "message": "Form deleted"
}
```

---

# Analytics Endpoints (Sudah Diimplementasikan)

## 1. Statistik Form

`GET /api/forms/{formId}/analytics?page=1&pageSize=20&search=john`

**Headers:** `Authorization: Bearer <token>` (pemilik form)

Menampilkan statistik lengkap form: total responden, skor tiap responden, rata-rata skor, detail jawaban.

**Query params (semua opsional):**
| Param | Keterangan |
|-------|------------|
| `page`, `pageSize` | Pagination responden di level database. Tanpa keduanya → semua responden dikirim (backward-compat). |
| `search` | Filter nama responden (nama akun login atau nama guest), case-insensitive `contains`. |

**Response 200 (dengan pagination):**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "totalResponses": 10,
    "totalQuestions": 5,
    "scorableQuestions": 3,
    "averageScore": 83.3,
    "respondents": [
      {
        "responseId": 1,
        "respondentName": "John Doe",
        "submittedAt": "2026-07-30T10:30:00Z",
        "answeredCount": 5,
        "totalQuestions": 5,
        "correctCount": 3,
        "scorableQuestions": 3,
        "score": 100.0,
        "answers": [
          {
            "questionId": 1,
            "question": "Apa warna langit?",
            "questionFormat": "text",
            "typeId": 1,
            "answerText": "Biru",
            "correctAnswer": "Biru",
            "isCorrect": true
          }
        ]
      }
    ],
    "page": 1,
    "pageSize": 20
  }
}
```

**Penjelasan:**
- `scorableQuestions` = jumlah soal yang memiliki kunci jawaban (CorrectAnswer atau opsi dengan IsCorrect)
- `score` = `correctCount / scorableQuestions * 100`, null jika tidak ada soal yang bisa diskor
- `averageScore` = rata-rata skor **semua** responden (tidak terpengaruh filter search/pagination)
- `isCorrect` = `true`/`false` untuk soal yang bisa diskor, `null` untuk soal survey
- Pagination & pencarian dieksekusi di database; hanya halaman aktif yang dimuat lengkap dengan jawabannya

---

# Template Endpoints (Sudah Diimplementasikan)

## 1. Download Template Import Soal

`GET /api/templates/import-questions?format=csv`

**Headers:** tidak perlu auth

Download template untuk import soal. Format: `csv`, `xlsx`, `docx`, `pdf`.

Returns file langsung (Content-Disposition: attachment).

---

# Planned Endpoints (Belum Diimplementasikan)

| Group | Endpoint | Method |
|-------|----------|--------|
| Forms | `/api/forms/{id}/duplicate` | POST |
| Forms | `/api/forms/{id}/save-template` | POST |
| Forms | `/api/forms/{formId}/share/token` | POST |
| Templates | `/api/templates` | GET |
| Templates | `/api/templates/{id}` | PUT, DELETE |
| Templates | `/api/templates/{templateId}/apply` | POST |

Daftar endpoint di atas bersumber dari dokumentasi perencanaan dan belum ada implementasi di controller.

