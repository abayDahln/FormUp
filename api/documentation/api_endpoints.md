# API Endpoints FormUp

**Status: Early Development** — hanya endpoint autentikasi yang sudah diimplementasikan.

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

# Planned Endpoints (Belum Diimplementasikan)

| Group | Endpoint | Method |
|-------|----------|--------|
| Users | `/api/users/me` | GET, PUT |
| Users | `/api/users/change-password` | POST |
| Users | `/api/users/me/stats` | GET |
| Forms | `/api/forms` | GET, POST |
| Forms | `/api/forms/{id}` | GET, PUT, DELETE |
| Forms | `/api/forms/{id}/publish` | POST |
| Forms | `/api/forms/{id}/duplicate` | POST |
| Forms | `/api/forms/{id}/save-template` | POST |
| Forms | `/api/forms/{formId}/share` | GET |
| Forms | `/api/forms/{formId}/share/qr` | GET |
| Forms | `/api/forms/{formId}/share/token` | POST |
| Questions | `/api/forms/{formId}/questions` | GET, POST |
| Questions | `/api/forms/{formId}/questions/reorder` | POST |
| Questions | `/api/questions/{id}` | PUT, DELETE |
| Responses | `/api/forms/{formId}/responses` | GET, POST |
| Responses | `/api/responses/{id}` | GET |
| Responses | `/api/responses/{id}/status` | PUT |
| Responses | `/api/forms/{formId}/responses/export` | GET |
| Analytics | `/api/forms/{formId}/analytics/summary` | GET |
| Analytics | `/api/forms/{formId}/analytics/questions/{id}` | GET |
| Analytics | `/api/forms/{formId}/analytics/performance` | GET |
| Templates | `/api/templates` | GET |
| Templates | `/api/templates/{id}` | PUT, DELETE |
| Templates | `/api/templates/{templateId}/apply` | POST |
| Uploads | `/api/uploads` | POST |
| Webhooks | `/api/webhooks` | POST |

Daftar endpoint di atas bersumber dari dokumentasi perencanaan (berkas lama `api_endpoints.md`) dan belum ada implementasi di controller.

