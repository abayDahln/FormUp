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

