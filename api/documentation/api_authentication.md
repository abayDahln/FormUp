# Autentikasi API FormUp

## Base URL

```
http://localhost:5000/api
```

## Token JWT di Header

Sertakan token di setiap request kecuali register dan login:

```
Authorization: Bearer <your-jwt-token>
```

## Endpoint Autentikasi

### 1. Register

**Endpoint:**
```
POST /api/auth/register
```

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

**Validasi:**
- `fullname` — wajib
- `username` — min 3 karakter, unik
- `email` — format valid, unik
- `password` — min 8 karakter
- `birthdate` — opsional, format `yyyy-MM-dd`
- `role` — opsional, default `"USER"`

**Response (201 Created):**
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

### 2. Login

**Endpoint:**
```
POST /api/auth/login
```

**Request:**
```json
{
  "email": "john@example.com",
  "password": "SecurePass123!"
}
```

**Response (200 OK):**
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

**Response (401):**
```json
{
  "status": 401,
  "message": "Invalid email or password",
  "data": null
}
```

---

### 3. Refresh Token

Token JWT berlaku **7 hari**. Refresh untuk mendapat token baru tanpa login ulang.

**Endpoint:**
```
POST /api/auth/refresh
```

**Headers:**
```
Authorization: Bearer <current-token>
```

**Note:** Tidak perlu body — token diambil dari header Authorization.

**Response (200 OK):**
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

### 4. Lupa Password (Kirim OTP)

**Endpoint:**
```
POST /api/auth/forgot-password
```

**Request:**
```json
{
  "email": "john@example.com"
}
```

**Response (200 OK):**
```json
{
  "status": 200,
  "message": "OTP has been sent to your email",
  "data": null
}
```

OTP dikirim via email, berlaku 15 menit.

---

### 5. Reset Password

**Endpoint:**
```
POST /api/auth/reset-password
```

**Request:**
```json
{
  "email": "john@example.com",
  "otp": "123456",
  "newPassword": "NewSecurePass456!"
}
```

**Response (200 OK):**
```json
{
  "status": 200,
  "message": "Password has been reset successfully",
  "data": null
}
```

---

## Error Handling

Semua response error dibungkus `ApiResponse<T>`:

```json
{
  "status": 401,
  "message": "Unauthorized",
  "data": null
}
```

Jika token expired, response juga menyertakan header `Token-Expired: true`.

---

## Config Environment

Di `appsettings.json` atau env var:

| Key | Env | Default |
|-----|-----|---------|
| `Jwt:Key` | `JWT_KEY` | — (wajib, min 32 karakter) |
| `Jwt:Issuer` | — | `FormUpAPI` |
| `Jwt:Audience` | — | `FormUpClient` |
| `Jwt:ExpiryMinutes` | — | `10080` (7 hari) |

