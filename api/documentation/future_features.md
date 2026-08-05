# FormUp — Fitur Tertunda (Deferred Features)

> Daftar fitur yang sengaja **tidak dibuat** saat MVP karena terlalu kompleks dan belum dibutuhkan. Semua kode terkait sudah dihapus dari backend. Implementasikan lagi nanti ketika project sudah stabil dan trafík responden cukup besar untuk membutuhkannya.

---

## 1. Honeypot (Anti-Bot Spam)

**Status:** dihapus dari `ResponseSubmission.cs`.

**Tujuan:** mencegah bot mengirim submit spam. Field tersembunyi (div CSS-hidden) di form HTML — manusia tidak akan mengisinya, bot yang auto-fill semua field akan terisi → backend membalas "sukses" palsu tanpa menyimpan apa-apa.

**Cara implementasi ulang:**
1. Tambah field `Honeypot` di `SubmitResponseRequest` (`ResponseDtos.cs`).
2. Di awal `ResponseSubmission.SaveAsync`, jika `Honeypot` terisi → balas `201` palsu tanpa menyimpan.

**Kapan dibutuhkan:** ketika responden publik mulai banyak dan spam submit mulai terlihat.

---

## 2. Idempotency-Key (Anti-Duplikat Submit)

**Status:** dihapus dari `ResponseSubmission.cs`, `Response` model, `FormUpDbContext` (kolom `idempotency_key` + unique index `UQ__Response__form_idempotency`).

**Tujuan:** klien mengirim nilai unik di header `Idempotency-Key`. Kalau responden double-tap submit atau jaringan retry, permintaan kedua dengan key yang sama tidak menyimpan duplikat — hanya mengembalikan `responseId` yang sama.

**Cara implementasi ulang:**
1. Tambah kolom `IdempotencyKey` (varchar 128) di tabel `Response` + unique index `(form_id, idempotency_key)`.
2. Baca header `Idempotency-Key` di `ResponseSubmission.SaveAsync`; jika ada response dengan key sama → balas `responseId` existing.

**Kapan dibutuhkan:** ketika klien web/mobile perlu retry submit yang aman di jaringan tidak stabil.

---

## 3. Respondent Fingerprint (One-Response untuk Responden Anonim)

**Status: ✅ sudah diimplementasi** dengan versi sederhana: kolom `guest_token` di tabel `Response`.

Klien mengirim `guestToken` persisten (mis. tersimpan di localStorage) di body submit. Dipakai untuk:
- Cek one-response untuk guest (`oneResponse = true` → submit kedua dengan token sama ditolak `400`).
- Mengambil hasil lewat `GET /api/public/forms/{link}/responses/{id}?token=<guestToken>`.

Jika klien tidak mengirim `guestToken`, server membuat GUID dan **mengembalikannya** di respons submit (`data.guestToken`).

**Peningkatan yang mungkin (deferred):** hash device/browser (fingerprint) untuk identitas yang lebih pasif tanpa bergantung klien. Tambah kolom `RespondentFingerprint` bila nanti butuh.

---

## Catatan

- Kolom `idempotency_key` sudah **dihapus** dari tabel `Response` di database. Kolom `respondent_fingerprint` juga sudah dihapus dan **digantikan** `guest_token` (lihat §3). Saat implementasi ulang, tambahkan lewat migration/SQL.
- Tambahkan fitur di atas **satu per satu**, jangan sekaligus, supaya dampaknya mudah diverifikasi.
