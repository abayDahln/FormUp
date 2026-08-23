# Public Form Endpoints (Responden, Tanpa Login)


Endpoint ini dipakai responden untuk mengerjakan form lewat link `/f/{code}` (web: route `/f/:code`, mobile: deep link). **Tidak butuh JWT** (kecuali form `requiresLogin`).

Alur 2-langkah agar **soal aman**: GET info+requirement dulu, baru POST `/questions` untuk ambil soal.

## 1. Ambil Info + Requirement Form Publik

`GET /api/public/forms/{formLink}`

Balas meta + requirement form, **tanpa soal**.

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
    "requiresToken": false,
    "requiresLogin": false,
    "showScore": true,
    "timerDuration": 300,
    "randomizeQuestions": false,
    "openFormTime": null,
    "closeFormTime": null
  }
}
```

**Gate — pesan dibedakan:**

| Kondisi | HTTP | Message |
|---------|------|---------|
| `formLink` tidak ada / soft-delete / takedown / status bukan `published` | 404 | `Form tidak ditemukan` |
| `openFormTime` belum lewat | 403 | `Form belum dibuka` (data berisi `openFormTime`) |
| `closeFormTime` sudah lewat | 403 | `Form sudah ditutup` (data berisi `closeFormTime`) |

## 2. Ambil Soal Publik

`POST /api/public/forms/{formLink}/questions`

Kirim JSON `{ token?, name? }`:
- `token` — wajib jika `requiresToken` true (token form).
- `name` — nama tamu (opsional, jika form tidak `requiresLogin`).

**Request:**
```json
{ "token": "abc123", "name": "Budi" }
```

**Validasi sebelum soal dikirim:**
- `requiresLogin = true` dan tidak bawa JWT → `401 Login required to access this form`
- Form ber-`FormToken` dan `token` salah/kosong → `401 Invalid or missing form token`
- Gate 404/403 open/closed sama seperti GET di atas

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "formId": 1,
    "questions": [
      {
        "id": 1,
        "typeId": 2,
        "question": "Apa warna langit?",
        "questionFormat": "text",
        "questionOrder": 1,
        "isRequired": true,
        "correctAnswer": null,
        "randomizeOptions": false,
        "options": [
          { "id": 1, "optionText": "Biru", "optionImage": null, "isCorrect": null, "optionOrder": 1 }
        ]
      }
    ]
  }
}
```

**Catatan anti-bocor:** `correctAnswer` dan `isCorrect` selalu `null`. `responseCount` tidak pernah dikirim.

## 3. Submit Response (Publik via Link)

`POST /api/public/forms/{formLink}/responses`

Sama persis seperti `POST /api/forms/{formId}/responses` (lihat Response Endpoints), tapi menerima `formLink`.

**Request:**
```json
{
  "token": "abc123",
  "respondentName": "Budi",
  "answers": [
    { "questionId": 1, "optionId": 2 },
    { "questionId": 2, "answerValue": "Jawaban text" }
  ]
}
```

**Response 201:**
```json
{
  "status": 201,
  "message": "Response submitted",
  "data": { "responseId": 1 }
}
```

- Simpan `responseId` untuk melihat hasil lewat endpoint di bawah.
- `oneResponse = true`: batasi satu respons per orang hanya untuk **user login** (dicek via `respondentId`) → submit kedua ditolak `400 You have already submitted a response`. Guest belum dipaksakan satu-respons.

**Rate limit:** policy `submit` — 60/menit per kombinasi IP + `formLink`.

## 4. Lihat Hasil (Responden)

`GET /api/public/forms/{formLink}/responses/{responseId}`

Akses:
- **Guest (tanpa akun):** respons guest bisa diakses siapa pun yang menyimpan link + `responseId` setelah submit (respons guest tidak memiliki identitas akun).
- **User login:** bawa JWT, hanya pemilik respons (`respondent_id`) yang boleh (`401` untuk user lain).

**Response 200 (jika `showScore = true`):**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "responseId": 1,
    "formId": 1,
    "formTitle": "Survey Kepuasan",
    "showScore": true,
    "score": 100.0,
    "correctCount": 2,
    "wrongCount": 0,
    "totalQuestions": 2,
    "scorableQuestions": 2,
    "answeredCount": 2,
    "answers": [
      {
        "questionId": 1,
        "question": "2+2 berapa?",
        "questionFormat": "text",
        "typeId": 1,
        "answerText": "4",
        "correctAnswer": "4",
        "isCorrect": true
      }
    ]
  }
}
```

**Jika `showScore = false`:** `score`, `correctCount`, `wrongCount` = 0/null dan per soal `correctAnswer`/`isCorrect` tidak dikirim (hanya jawaban responden).

## 5. Riwayat Attempt Saya pada Satu Form (User Login)

`GET /api/public/forms/{formLink}/my-responses`

**Headers:** `Authorization: Bearer <token>`

Mengembalikan semua attempt user yang sedang login untuk form ini, terbaru lebih dulu — dipakai tab Riwayat (pengelompokan per form) dan pemilih attempt.

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "responseId": 12,
      "submittedAt": "2026-08-22T09:15:00Z",
      "showScore": true,
      "score": 87.5,
      "correctCount": 7,
      "wrongCount": 1
    }
  ]
}
```

Catatan: `showScore`, `score`, `correctCount`, `wrongCount` mengikuti pengaturan form; `score` `null` jika form tidak menampilkan nilai. Tidak mensyaratkan form masih `published` — riwayat tetap bisa dibuka walau form sudah di-unpublish.

---

