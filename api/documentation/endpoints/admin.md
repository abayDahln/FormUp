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

