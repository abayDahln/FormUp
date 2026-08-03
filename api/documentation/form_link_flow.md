# Form Link Flow — Mengerjakan Form via `/f/{code}`

## 1. Masalah Inti

Backend **tidak punya endpoint publik** yang menerima `FormLink` (short link).
- `ShareUrl` & QR sudah generate `/f/{formLink}` (`FormsController.cs:334/355`).
- Tapi semua GET form/soal butuh auth owner (`FormsController.cs:53`, `QuestionsController.cs:19`).
- `POST api/forms/{formId}/responses` sudah publik (`ResponsesController.cs:21`), tapi butuh `formId` angka — responden cuma pegang `code`.

Akibatnya link `/f/{code}` terasa "mati": tidak bisa dikerjakan dari web maupun mobile.

## 2. Arsitektur yang Disepakati

`/f/{code}` **bukan endpoint backend**, melainkan kepemilikan *client*. Backend hanya menyediakan 2 endpoint publik yang dibagikan web & mobile.

```
DB: Form.FormLink = "abc123"  (default generate 12 char saat create: FormsController.cs; bisa diedit pemilik via PUT /api/forms/{id} → unik global, index unik via DBContext.cs:52)

Share URL: {host}/f/abc123    (FormsController.cs:334/355, QR pun untuk itu)

Web  : buka localhost:5173/f/abc123
       → SPA route /f/:code  → baca code
       → GET  /api/public/forms/abc123            (form + questions)
       → POST /api/public/forms/abc123/responses  (submit)

Mobile (user sudah install app):
       → deep link / app link menangkap "abc123"
       → GET & POST yang SAMA ke /api/public/forms/abc123
```

**Keputusan arah: murni API.** Backend tidak punya halaman `/f/{code}`. Resolver `GET /f/{code}` (redirect) dijadikan opsi cadangan — lihat §8.

## 3. Perubahan Backend

### 3.1 Refactor tempat submit (supaya tidak duplikat)
- File baru `api/Services/ResponseSubmission.cs`: static helper.
- Pindah isi `ResponsesController.Submit` (gate status/waktu/token, one-response, validasi soal, simpan `Response` + `RespondentAnswer`) ke helper. (Honeypot, idempotency-key, dan fingerprint **tidak ikut dipindah** — fitur itu sudah dihapus, lihat `future_features.md`.)
- Signature aktual:
```csharp
public static async Task<ActionResult> SaveAsync(
    FormUpDbContext db, ClaimsPrincipal user,
    int formId, SubmitResponseRequest body)
```
- `ResponsesController.Submit` tinggal memanggil helper (mengurangi ~100 baris → 5 baris).

### 3.2 Controller baru `api/Controllers/PublicFormsController.cs`
`[Route("api/public")]`, controller `[ApiController]`, method-method `[AllowAnonymous]`.

**`GET forms/{formLink}`** → payload responden
1. Resolve `Form` (Include FormSetting) by `FormLink`.
2. Gate: jika `form == null || TakenDownAt != null || status != published` → `404` generik `"Form not found or unavailable"` (pola anti link-guessing dari Responses.cs:34-48). Juga blokir bila `CloseFormTime` lewat.
3. Token: jika `FormSetting.FormToken` terisi → `requiresToken=true`; soal hanya dikirim jika query `?token=` cocok; bila salah/tidak ada → `401` generik.
4. Response JSON: `{ id, title, description, bannerImage, requiresToken, showScore, timerDuration, randomizeQuestions, questions[] }`.

**`POST api/public/forms/{formLink}/responses`**, `[EnableRateLimiting("submit")]`
1. Resolve + gate `Form` di atas.
2. Panggil `ResponseSubmission.SaveAsync(db, User, Request, formId, body)`.
3. Balas sama seperti implementation.

### 3.3 DTO minim (anti-bocoran)
- Reuse `SubmitResponseRequest` (ResponseDtos.cs:3). DTO lama `QuestionResponse` (QuestionDtos.cs:9) **bocorkan** `CorrectAnswer` & `Option.IsCorrect` — jangan dipakai langsung untuk publik.
- Tambah di `Models/FormDtos.cs` DTO `PublicFormDetails` (meta + `List<QuestionResponse>`), berisi: untuk tiap soal copy `QuestionResponse` tapi set `CorrectAnswer = null` dan tiap `OptionResponse.IsCorrect = null`. Beri komentar `// ponytail: mapper publik, jangan bocorkan kunci`.

## 4. Web Frontend (SPA — nanti saat dibangun)
- Route baru `/f/:code` (react-router-dom; ditambahkan di `App.jsx`).
- Komponen FormRunner: baca `useParams().code` → `GET /api/public/forms/{code}` → tampilkan soal → isi → `POST .../responses`.
- Jika server balas 401/404 → tampilkan "Form not found atau tidak tersedia".

## 5. Mobile (Flutter — nanti saat dibangun)
- Tambah `app_links`/`uni_links` (deep link) + Android `intent-filter` / iOS `Associated Domains` untuk host `/f/*`.
- Ekstrak `code` → panggil `GET/POST api/public/forms/{code}` (lewat `auth_service.dart` atau service baru).

## 6. Segitiga Kata (anti bocor) — yang WAJIB
- Kejawabannya: `correctAnswer`/`isCorrect` **null** di GET publik.
- `closed` / `taken-down` / `CloseFormTime` lewat → `404` generik (cermin perilaku Submit yang sudah ada, Responses.cs:41-48).
- `ResponseCount` (jumlah responden) **jangan** bocor ke GET publik (data internal creator; DTO `FormDetailResponse.cs:76` memintanya).

## 7. Verifikasi (di `api/`, manual lewat Swagger)
1. Login → buat + publish form dengan beberapa soal (1 multiple-choice ber-`IsCorrect`).
2. `GET api/public/forms/{formLink}` → assert `correctAnswer` null, `isCorrect` null, meta utuh.
3. `POST api/public/forms/{formLink}/responses` → sukses (`201`).
4. Form ber-`FormToken` → GET tanpa token `401`, dengan token benar `200`.
5. Form `closed`/`TakenDownAt` → `404` generik.
6. Jalankan `dotnet build`; tidak ada error.

## 8. Out of Scope (YAGNI)
- Halaman HTML server-rendered untuk `/f/{code}` — **tidak dibuat**.
- DTO lengkap baru — reuse di atas + null.
- Fitur "login wajib untuk restricted" di endpoint publik — token cukup untuk sekarang; jika ada enum `Restricted` dari `FormSetting` nanti, tambah cek.
- Resolver `/f/{code}` di backend (redirect ke frontend) — opsi, tambah kapan perlu kalau pemegang link membuka domain API langsung.