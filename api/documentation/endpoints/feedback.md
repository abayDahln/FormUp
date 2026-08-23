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

