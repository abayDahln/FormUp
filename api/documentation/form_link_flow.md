# Form Link Flow — Mengerjakan Form via `/f/{code}`

## 1. Masalah Inti

Backend **tidak punya halaman** `/f/{code}` — `/f/{code}` milik client (SPA web / deep link mobile). Backend menyediakan endpoint publik yang menerima `FormLink`.

Supaya **soal tetap aman**, soal tidak lagi ikut di GET pertama. Alur menjadi 3 langkah:
1. Klien minta **info + requirement** form (apakah perlu login, perlu token, timer, dsb) — tanpa soal.
2. Klien kirim **token/name** untuk mengambil soal (`/questions`) — soal baru dikirim setelah requirement terpenuhi.
3. Klien kirim jawaban (`/responses`) dan bisa melihat **hasil** (`/responses/{id}`).

## 2. Arsitektur

```
DB: Form.FormLink = "abc123"  (default 12 char saat create; unik global)

Share URL: {host}/f/abc123   (FormsController share & QR)

Web / Mobile (client):
  step 1  GET  /api/public/forms/abc123                    → info form + requirement (TANPA soal)
  step 2  POST /api/public/forms/abc123/questions          → body {token?, name?}; validasi; balas soal
  step 3  POST /api/public/forms/abc123/responses          → submit; balas {responseId, guestToken}
  step 4  GET  /api/public/forms/abc123/responses/{id}?token=... → hasil (nilai, benar/salah)
```

**Keputusan arah: murni API.** Backend tidak punya halaman `/f/{code}`.

## 3. Endpoint Publik (`api/Controllers/PublicFormsController.cs`)

`[Route("api/public")]`, controller `[ApiController]`, semua method `[AllowAnonymous]`.

### 3.1 `GET forms/{formLink}` — Info + Requirement (tanpa soal)

Resolve `Form` (Include FormSetting) by `FormLink`. Balas meta + requirement:

```json
{
  "status": 200, "message": "OK",
  "data": {
    "id": 1, "title": "...", "description": "...", "bannerImage": null,
    "requiresToken": false,
    "requiresLogin": false,
    "showScore": true, "timerDuration": 300, "randomizeQuestions": false,
    "openFormTime": null, "closeFormTime": null
  }
}
```

**Gate — pesan dibedakan (bukan lagi 404 generik):**

| Kondisi | HTTP | Message |
|---------|------|---------|
| `formLink` tidak ada / soft-delete / takedown / status bukan published | 404 | `Form tidak ditemukan` |
| `openFormTime` belum lewat (form belum dibuka) | 403 | `Form belum dibuka` (+ `data.openFormTime`) |
| `closeFormTime` sudah lewat (form sudah ditutup) | 403 | `Form sudah ditutup` (+ `data.closeFormTime`) |

### 3.2 `POST forms/{formLink}/questions` — Ambil Soal (requirement dulu)

Body `{ token?, name? }` (`PublicQuestionsRequest`). Validasi `CheckAccess` sebelum soal dikirim:

| Requirement | Validasi | Gagal |
|-------------|----------|-------|
| `requiresLogin = true` | user wajib bawa JWT valid | 401 `Login required to access this form` |
| `FormToken` terisi | `body.token` harus cocok | 401 `Invalid or missing form token` |

Balas `{ formId, questions[] }`. Mapper `MapPublicQuestion` **tidak bocorkan** `CorrectAnswer` / `Option.IsCorrect` (selalu `null`).

### 3.3 `POST forms/{formLink}/responses` — Submit

Meneruskan ke `ResponseSubmission.SaveAsync`. Body `SubmitResponseRequest`:

```json
{
  "token": "abc123",
  "respondentName": "Guest Name",
  "guestToken": "kode-unik-dari-client",
  "answers": [ { "questionId": 1, "optionId": 2 } ]
}
```

Perilaku `SaveAsync`:
- Gate open/closed/status seperti di atas (pesan dibedakan).
- `requiresLogin` → tanpa JWT ditolak 401.
- `FormToken` → `body.token` harus cocok.
- `oneResponse = true` → user login dicek via `respondentId`; **guest dicek via `guestToken`** yang sama (client harus mengirim `guestToken` yang persisten, mis. localStorage). Jika sudah pernah submit → `400 You have already submitted a response`.
- Guest otomatis diberi `guestToken` (GUID) bila tidak mengirim; **dikembalikan di respons** supaya client bisa ambil hasil:
```json
{ "status": 201, "message": "Response submitted", "data": { "responseId": 1, "guestToken": "..." } }
```
(`guestToken` `null` untuk user login.)

### 3.4 `GET forms/{formLink}/responses/{responseId}` — Lihat Hasil

Ambil hasil respons milik **responden itu sendiri**:
- Guest: wajib `?token=<guestToken>` yang cocok dengan `response.guest_token`.
- User login: JWT; hanya pemilik respons (`respondent_id`) yang boleh lihat. User lain → 401.
- Form tidak ditemukan → 404; respons tidak ada → 404; token salah → 401.

**Skor dibatasi setting `showScore`:**
- `showScore = true` → tampil `score`, `correctCount`, `wrongCount`, dan per soal `correctAnswer` + `isCorrect`.
- `showScore = false` → hanya `answers` (jawaban responden), tanpa grading/skor.

Struktur: `{ responseId, formId, formTitle, showScore, score, correctCount, wrongCount, totalQuestions, scorableQuestions, answeredCount, answers[] }`. Logika skoring ada di `Services/ResponseScorer.cs` (dipakai juga oleh `AnalyticsController`).

## 4. DTO anti-bocor

- `PublicFormDetails` (meta + requirement, **tanpa** `Questions`).
- `PublicQuestionsRequest` (`token`, `name`), `PublicQuestionsResponse` (`formId`, `questions`).
- Mapper publik `MapPublicQuestion` menyalin `QuestionResponse` tapi set `CorrectAnswer = null` dan tiap `OptionResponse.IsCorrect = null`.

## 5. History User Login

`GET /api/users/me/responses` (auth) → daftar form yang pernah dikerjakan. Untuk melihat hasil satu respons, panggil endpoint hasil publik (§3.4) dengan JWT milik pemilik respons.

## 6. Segitiga Kata (anti bocor)

- `correctAnswer` / `isCorrect` selalu `null` di endpoint soal publik.
- Skor / jawaban benar / benar-salah hanya tampil di endpoint **hasil** dan jika `showScore = true`.
- `ResponseCount` tidak pernah dikirim ke endpoint publik.

## 7. Verifikasi (di `api/`, manual)

1. Login → buat + publish form berisi 1 essay ber-`correctAnswer` + 1 multiple-choice ber-`isCorrect`, `showScore = true`.
2. `GET api/public/forms/{formLink}` → hanya meta, `questions` tidak ada, ada `requiresLogin`/`openFormTime`/`closeFormTime`.
3. `POST .../questions` tanpa token (form ber-token) → 401; dengan token benar → 200, `correctAnswer` null.
4. `POST .../responses` sebagai guest → 201 + `guestToken`.
5. `GET .../responses/{id}?token=<guestToken>` → score 100, tiap soal tampil `correctAnswer` + `isCorrect`.
6. Set `showScore = false` → hasil tanpa grading.
7. `openFormTime` di masa depan → GET 403 `Form belum dibuka`; `closeFormTime` lewat → 403 `Form sudah ditutup`.
8. `oneResponse = true`, submit kedua dengan `guestToken` sama → 400.
9. `dotnet build` → 0 error.

## 8. Out of Scope (YAGNI)

- Halaman HTML server-rendered untuk `/f/{code}` — tidak dibuat.
- Honeypot / Idempotency-Key — tetap di `future_features.md` (belum dibutuhkan).
