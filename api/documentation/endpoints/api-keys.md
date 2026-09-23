# API Key Endpoints (Redeem Gemini API Key)

Butuh JWT (wajib login). Satu API key punya satu kode/PW (disimpan sebagai
hash `salt.hash`, sama seperti password). Satu kode bisa dipakai banyak user.

## 1. Redeem Kode → API Key

`POST /api/api-keys/redeem`

Rate-limit 10/menit (anti brute-force kode).

**Request:**
```json
{
  "code": "KELAS12A-2026"
}
```

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "label": "Kelas XII-A",
    "apiKey": "AIza..."
  }
}
```

**Response 400** — kode kosong:
```json
{ "status": 400, "message": "Kode wajib diisi." }
```

**Response 404** — kode salah ATAU key nonaktif (pesan disamakan agar tak
membocorkan key mana yang ada):
```json
{ "status": 404, "message": "Kode tidak valid." }
```

**Response 401** — belum login:
```json
{ "status": 401, "message": "Unauthorized" }
```

**Catatan:**
- Redeem bersifat idempoten: user yang sama menebus kode yang sama
  berkali-kali tetap sukses (tidak duplikat catatan).
- Siapa menebus dicatat di `GeminiApiKeyRedemption` + counter
  `redeemed_count` di `GeminiApiKey`.
- Bandingkan kode dengan `string.Equals(code.Trim(), ...)` di sisi user —
  server sudah men-trim sebelum verifikasi hash.

---

## 2. Isi Key via SQL (tak ada endpoint admin)

`code_hash` memakai format `salt.hash` PBKDF2-SHA256 100.000 iterasi
(lihat `PasswordHelper` di `Models/User.cs`). Contoh insert (ganti
`CODE_HASH` dengan hash kode yang diinginkan):

```sql
INSERT INTO GeminiApiKey (label, api_key, code_hash, is_active, redeemed_count)
VALUES ('Kelas XII-A', 'AIza...', 'CODE_HASH', 1, 0);
```

Nonaktifkan key tanpa menghapus baris (riwayat redeem tetap utuh):

```sql
UPDATE GeminiApiKey SET is_active = 0, updated_at = GETUTCDATE() WHERE id = 1;
```

Lihat siapa menebus key:

```sql
SELECT r.redeemed_at, u.fullname, u.email, k.label
FROM GeminiApiKeyRedemption r
JOIN [User] u ON u.id = r.user_id
JOIN GeminiApiKey k ON k.id = r.key_id
WHERE r.key_id = 1
ORDER BY r.redeemed_at DESC;
```
