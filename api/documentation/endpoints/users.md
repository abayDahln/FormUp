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

