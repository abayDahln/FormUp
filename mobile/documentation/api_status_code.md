# Status Codes dan Response Format

## HTTP Status Codes

### Success Responses (2xx)

| Code | Status | Keterangan |
|------|--------|-----------|
| 200 | OK | Request berhasil, data direturn dalam response |
| 201 | Created | Resource berhasil dibuat |
| 204 | No Content | Request berhasil tapi tidak ada data yang direturn |

**Contoh Success Response (200 OK):**

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "fullname": "John Doe",
    "email": "john@example.com"
  }
}
```

**Contoh Created Response (201 Created):**

```json
{
  "data": {
    "id": "660f8400-e29b-41d4-a716-446655440001",
    "title": "Customer Satisfaction Survey",
    "status": "draft",
    "created_at": "2026-01-15T10:35:00Z"
  }
}
```

---

### Client Error Responses (4xx)

| Code | Status | Keterangan |
|------|--------|-----------|
| 400 | Bad Request | Request tidak valid atau parameter tidak lengkap |
| 401 | Unauthorized | Token tidak ada, expired, atau invalid |
| 403 | Forbidden | User tidak punya akses ke resource ini |
| 404 | Not Found | Resource tidak ditemukan |
| 409 | Conflict | Ada konflik dengan data yang ada (misal: email sudah terdaftar) |
| 422 | Unprocessable Entity | Validasi data gagal |
| 429 | Too Many Requests | Request terlalu sering (rate limit exceeded) |

**Contoh Bad Request (400):**

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Validasi gagal",
  "details": {
    "email": "Email harus punya format valid",
    "password": "Password minimal 8 karakter"
  },
  "trace_id": "1234567890"
}
```

**Contoh Unauthorized (401):**

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 401,
  "error": "Unauthorized",
  "message": "Token expired atau invalid. Silakan login ulang",
  "trace_id": "1234567890"
}
```

**Contoh Forbidden (403):**

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 403,
  "error": "Forbidden",
  "message": "Anda tidak punya akses ke resource ini",
  "trace_id": "1234567890"
}
```

**Contoh Not Found (404):**

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 404,
  "error": "Not Found",
  "message": "Form dengan ID tersebut tidak ditemukan",
  "trace_id": "1234567890"
}
```

**Contoh Conflict (409):**

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 409,
  "error": "Conflict",
  "message": "Email ini sudah terdaftar. Silakan gunakan email lain",
  "trace_id": "1234567890"
}
```

**Contoh Unprocessable Entity (422):**

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 422,
  "error": "Unprocessable Entity",
  "message": "Validasi data gagal",
  "details": {
    "title": "Title form wajib diisi",
    "email": "Format email tidak valid"
  },
  "trace_id": "1234567890"
}
```

**Contoh Too Many Requests (429):**

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 429,
  "error": "Too Many Requests",
  "message": "Anda telah mencapai batas request. Coba lagi dalam 60 detik",
  "retry_after": 60,
  "trace_id": "1234567890"
}
```

---

### Server Error Responses (5xx)

| Code | Status | Keterangan |
|------|--------|-----------|
| 500 | Internal Server Error | Terjadi error di server, bukan karena client |

**Contoh Internal Server Error (500):**

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 500,
  "error": "Internal Server Error",
  "message": "Terjadi error tidak terduga. Admin sudah diberitahu",
  "trace_id": "1234567890"
}
```

---

## Response Format Standard

### Format Success dengan Pagination

Digunakan untuk endpoint yang mengembalikan list data:

```json
{
  "data": [
    {
      "id": "660f8400-e29b-41d4-a716-446655440001",
      "title": "Customer Satisfaction Survey",
      "status": "published",
      "created_at": "2026-01-15T10:35:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 245,
    "total_pages": 13
  }
}
```

### Format Error dengan Details

Untuk error dengan detail validasi:

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 422,
  "error": "Unprocessable Entity",
  "message": "Validasi data gagal",
  "details": {
    "email": "Email harus punya format valid",
    "password": "Password minimal 8 karakter, harus punya huruf besar, kecil, dan angka",
    "fullname": "Fullname wajib diisi"
  },
  "trace_id": "1234567890"
}
```

---

## Rate Limiting

API implementasikan rate limiting untuk mencegah abuse.

### Header Response

Setiap response akan punya header berikut:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1642246860
```

**Penjelasan:**
- `X-RateLimit-Limit`: Jumlah request per menit yang diperbolehkan
- `X-RateLimit-Remaining`: Jumlah request yang masih bisa dilakukan
- `X-RateLimit-Reset`: Waktu (Unix timestamp) kapan limit direset

### Rate Limit Tiers

| Tier | Request per Menit | Harga |
|------|------------------|-------|
| Free | 100 | Gratis |
| Pro | 1,000 | $9/bulan |
| Enterprise | Unlimited | Custom |

### Contoh Ketika Rate Limit Terlampaui

Jika Anda mencapai rate limit, API akan return status code 429:

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 429,
  "error": "Too Many Requests",
  "message": "Anda telah mencapai batas 100 request per menit. Coba lagi dalam 60 detik",
  "retry_after": 60,
  "rate_limit": {
    "limit": 100,
    "remaining": 0,
    "reset": 1642246860
  },
  "trace_id": "1234567890"
}
```

---

## Handling Response di Client

### Contoh dengan JavaScript/Fetch

```javascript
async function createForm(formData, token) {
  try {
    const response = await fetch('https://api.formup.com/api/forms', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(formData)
    });

    // Cek status code
    if (!response.ok) {
      const errorData = await response.json();
      
      if (response.status === 401) {
        // Token expired, refresh atau login ulang
        console.log('Token expired:', errorData.message);
      } else if (response.status === 422) {
        // Validasi error
        console.log('Validation errors:', errorData.details);
      } else if (response.status === 429) {
        // Rate limit exceeded
        console.log(`Coba lagi dalam ${errorData.retry_after} detik`);
      } else {
        console.log('Error:', errorData.message);
      }
      throw new Error(errorData.message);
    }

    const data = await response.json();
    return data.data;
  } catch (error) {
    console.error('Request failed:', error);
    throw error;
  }
}
```

---

## Common Error Scenarios

### Scenario 1: Email Sudah Terdaftar

**Request:**
```bash
curl -X POST https://api.formup.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "existing@example.com",
    "password": "SecurePass123!",
    "fullname": "John Doe",
    "username": "johndoe"
  }'
```

**Response (409 Conflict):**
```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 409,
  "error": "Conflict",
  "message": "Email sudah terdaftar. Silakan gunakan email lain atau login",
  "trace_id": "1234567890"
}
```

---

### Scenario 2: Password Tidak Memenuhi Requirement

**Request:**
```bash
curl -X POST https://api.formup.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "password": "weak",
    "fullname": "John Doe",
    "username": "johndoe"
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 422,
  "error": "Unprocessable Entity",
  "message": "Validasi data gagal",
  "details": {
    "password": "Password harus minimal 8 karakter dan harus punya huruf besar, huruf kecil, angka, dan karakter spesial"
  },
  "trace_id": "1234567890"
}
```

---

### Scenario 3: Form Tidak Ditemukan

**Request:**
```bash
curl -X GET https://api.formup.com/api/forms/invalid-id \
  -H "Authorization: Bearer <token>"
```

**Response (404 Not Found):**
```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 404,
  "error": "Not Found",
  "message": "Form dengan ID 'invalid-id' tidak ditemukan",
  "trace_id": "1234567890"
}
```

---

### Scenario 4: User Tidak Punya Akses

**Request:**
```bash
curl -X GET https://api.formup.com/api/forms/form-milik-user-lain \
  -H "Authorization: Bearer <your-token>"
```

**Response (403 Forbidden):**
```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 403,
  "error": "Forbidden",
  "message": "Anda tidak punya akses untuk melihat form ini. Hanya pemilik form atau admin yang bisa mengakses",
  "trace_id": "1234567890"
}
```

---

## Best Practices

1. **Selalu cek status code** - Jangan hanya asumsikan request berhasil
2. **Handle error gracefully** - Tampilkan pesan error yang user-friendly
3. **Retry dengan exponential backoff** - Jika dapat 429, tunggu dan retry
4. **Log error details** - Simpan trace_id untuk debugging
5. **Validate input** - Validasi data client-side sebelum send ke API
6. **Handle timeout** - Set timeout untuk setiap request (biasanya 30 detik)