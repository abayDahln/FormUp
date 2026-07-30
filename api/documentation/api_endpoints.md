# API Endpoints FormUp

**Status: Development** — seluruh endpoint auth, user, form, question, response, feedback, admin, dan analytics sudah diimplementasikan.

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

## 1. Register

`POST /api/auth/register`

**Request:**
```json
{
  "fullname": "John Doe",
  "username": "johndoe",
  "email": "john@example.com",
  "password": "SecurePass123!",
  "birthdate": "1990-01-15"
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

---

## 2. Login

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

## 3. Refresh Token

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

## 4. Lupa Password

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

## 5. Reset Password

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

---

# Form Endpoints (Sudah Diimplementasikan)

## 1. Buat Form

`POST /api/forms`

**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "title": "Survey Kepuasan",
  "description": "Form survey untuk mengukur kepuasan pelanggan"
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
    "bannerImage": null,
    "formLink": "abc123def",
    "status": "draft",
    "responseCount": 0,
    "createdAt": "2026-07-28T10:30:00Z",
    "updatedAt": "2026-07-28T10:30:00Z"
  }
}
```

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
    "bannerImage": null,
    "formLink": "abc123def",
    "status": "draft",
    "responseCount": 0,
    "settings": {
      "showScore": null,
      "randomizeQuestions": null,
      "timerDuration": null,
      "oneResponse": null,
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
  "description": "Deskripsi baru"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "Form updated",
  "data": { ... }
}
```

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
  "showScore": true,
  "randomizeQuestions": false,
  "formToken": "abc123",
  "timerDuration": 300,
  "oneResponse": true,
  "closeFormTime": "2026-12-31T23:59:59Z"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "Settings updated",
  "data": {
    "showScore": true,
    "randomizeQuestions": false,
    "timerDuration": 300,
    "oneResponse": true,
    "closeFormTime": "2026-12-31T23:59:59Z"
  }
}
```

**Notes:**
- Jika `FormSetting` row belum ada, akan auto-create saat pertama kali di-PATCH
- `formToken` bisa di-set ke `null` dengan mengirim `"formToken": null`
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

# Question Endpoints (Sudah Diimplementasikan)

## 1. Daftar Pertanyaan

`GET /api/forms/{formId}/questions`

**Headers:** `Authorization: Bearer <token>`

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

**Request:**
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

**Response 201:** Array questions dengan ID masing-masing.

---

## 3. Ganti Semua Questions (Replace)

`PUT /api/forms/{formId}/questions`

**Headers:** `Authorization: Bearer <token>`

Hapus semua soal lama (soft delete) + ganti dengan yang baru. Body sama seperti create.

**Response 200:** Array questions baru.

---

## 4. Upload Image Question

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

## 5. Upload Audio Question

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

## 6. Import Soal dari File

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
- Jika `closeFormTime` sudah lewat → ditolak
- Jika form memerlukan token → body wajib menyertakan `token` yang sesuai
- Jika `oneResponse = true` dan user sudah pernah submit → ditolak
- `questionId` harus milik form tersebut

**Response 201:**
```json
{
  "status": 201,
  "message": "Response submitted",
  "data": { "responseId": 1 }
}
```

---

## 2. Daftar Responses (Owner)

`GET /api/forms/{formId}/responses`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "id": 1,
      "respondentName": "John Doe",
      "status": "new",
      "submittedAt": "2026-07-28T10:30:00Z"
    }
  ]
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
        "typeId": 1,
        "optionId": 2,
        "optionText": "Biru",
        "answerValue": null
      },
      {
        "questionId": 2,
        "question": "Komentar",
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

## 4. Update Status Response (Owner)

`PUT /api/responses/{id}/status`

**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "statusId": 2
}
```

Status: 1=new, 2=reviewed, 3=flagged.

**Response 200:**
```json
{
  "status": 200,
  "message": "Status updated"
}
```

---

## 5. Export Responses (Owner)

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

`GET /api/forms/{formId}/analytics`

**Headers:** `Authorization: Bearer <token>` (pemilik form)

Menampilkan statistik lengkap form: total responden, skor tiap responden, rata-rata skor, detail jawaban.

**Response 200:**
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
            "typeId": 1,
            "answerText": "Biru",
            "correctAnswer": "Biru",
            "isCorrect": true
          },
          {
            "questionId": 2,
            "question": "2+2 berapa?",
            "typeId": 3,
            "answerText": "5",
            "correctAnswer": "4",
            "isCorrect": false
          },
          {
            "questionId": 3,
            "question": "Komentar",
            "typeId": 4,
            "answerText": "Bagus",
            "correctAnswer": null,
            "isCorrect": null
          }
        ]
      }
    ]
  }
}
```

**Penjelasan:**
- `scorableQuestions` = jumlah soal yang memiliki kunci jawaban (CorrectAnswer atau opsi dengan IsCorrect)
- `score` = `correctCount / scorableQuestions * 100`, null jika tidak ada soal yang bisa diskor
- `averageScore` = rata-rata skor semua responden
- `isCorrect` = `true`/`false` untuk soal yang bisa diskor, `null` untuk soal survey

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

