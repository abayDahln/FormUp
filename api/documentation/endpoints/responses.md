# Response Endpoints (Sudah Diimplementasikan)


## 1. Submit Response (Publik)

`POST /api/forms/{formId}/responses`

**Headers:** (opsional) `Authorization: Bearer <token>` untuk user login, <br>
**Token:** kirim `token` di body jika form memerlukan token akses.

**Request:**
```json
{
  "token": null,
  "respondentName": "Budi",
  "answers": [
    { "questionId": 1, "optionId": 2 },
    { "questionId": 2, "answerValue": "Jawaban text" },
    { "questionId": 3, "optionId": null, "answerValue": "Bebas" }
  ]
}
```

Untuk pilihan ganda: kirim `optionId`. Untuk text: kirim `answerValue`.

**Validasi:**
- Form harus berstatus `published`
- Jika `openFormTime` belum lewat → `403 Form belum dibuka`
- Jika `closeFormTime` sudah lewat → `403 Form sudah ditutup`
- Jika `requiresLogin = true` → wajib bawa JWT (tanpa login → `401`)
- Jika form memerlukan token → body wajib menyertakan `token` yang sesuai
- Jika `oneResponse = true` dan sudah pernah submit → ditolak `400` (dicek via `respondent_id`, hanya untuk user login)
- `questionId` harus milik form tersebut

**Response 201:**
```json
{
  "status": 201,
  "message": "Response submitted",
  "data": { "responseId": 1 }
}
```

- Simpan `responseId` untuk melihat hasil lewat endpoint detail/hasil.

---

## 2. Daftar Responses (Owner)

`GET /api/forms/{formId}/responses?page=1&pageSize=20`

**Headers:** `Authorization: Bearer <token>`

Mendukung pagination: kirim `page` + `pageSize` → respons `{items, total, page, pageSize}`; tanpa parameter → array penuh (backward-compat).

**Response 200 (dengan pagination):**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "items": [
      {
        "id": 1,
        "respondentName": "John Doe",
        "status": "new",
        "submittedAt": "2026-07-28T10:30:00Z"
      }
    ],
    "total": 42,
    "page": 1,
    "pageSize": 20
  }
}
```

---

## 3. Detail Response (Owner)

`GET /api/forms/{formId}/responses/{id}`

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "id": 1,
    "formId": 1,
    "respondentName": "John Doe",
    "status": "new",
    "submittedAt": "2026-07-28T10:30:00Z",
    "answers": [
      {
        "questionId": 1,
        "question": "Apa warna langit?",
        "questionFormat": "text",
        "typeId": 1,
        "optionId": 2,
        "optionText": "Biru",
        "answerValue": null
      },
      {
        "questionId": 2,
        "question": "Komentar",
        "questionFormat": "text",
        "typeId": 4,
        "optionId": null,
        "optionText": null,
        "answerValue": "Bagus"
      }
    ]
  }
}
```

---

## 4. Hasil Lengkap Response (Owner)

`GET /api/forms/{formId}/responses/{id}/result`

**Headers:** `Authorization: Bearer <token>`

Hasil lengkap satu respons milik responden — format identik dengan endpoint hasil publik (`ResponseScorer.BuildResult`): skor, kunci jawaban, opsi tiap soal, dan `selectedOptions` (semua opsi/teks yang dipilih responden; penting untuk checkbox multi-pilihan). Dipakai screen Respondent Detail.

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "responseId": 1,
    "formId": 1,
    "formTitle": "Quiz Matematika",
    "showScore": true,
    "score": 87.5,
    "correctCount": 7,
    "wrongCount": 1,
    "totalQuestions": 8,
    "scorableQuestions": 8,
    "answeredCount": 8,
    "answers": [
      {
        "questionId": 1,
        "question": "2+2 berapa?",
        "questionFormat": "text",
        "typeId": 3,
        "answerText": "4",
        "correctAnswer": "4",
        "isCorrect": true,
        "options": ["3", "4", "5"],
        "selectedOptions": ["4"]
      }
    ]
  }
}
```

---

## 5. Attempt Lain Responden yang Sama (Owner)

`GET /api/forms/{formId}/responses/{id}/attempts`

**Headers:** `Authorization: Bearer <token>`

Daftar semua attempt responden yang sama pada form yang sama — dicocokkan via akun login (`respondent_id`); untuk guest memakai pencocokan nama (`respondent_name`). Diurutkan terbaru lebih dulu.

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

---

## 6. Update Status Response (Owner)

`PUT /api/responses/{id}/status`

**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "statusId": 2
}
```

Status: 1=new, 2=reviewed, 3=flagged.

> **Catatan UI:** opsi ubah status (accept/reject) sudah dihapus dari aplikasi mobile; endpoint ini masih tersedia untuk kompatibilitas.

**Response 200:**
```json
{
  "status": 200,
  "message": "Status updated"
}
```

---

## 7. Export Responses (Owner)

`GET /api/forms/{formId}/responses/export`

**Headers:** `Authorization: Bearer <token>`

Returns file CSV langsung (Content-Type: `text/csv`).

Kolom: Response ID, Submitted At, Respondent, [jawaban per pertanyaan], Status.

---

