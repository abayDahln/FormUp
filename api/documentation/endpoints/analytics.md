# Analytics Endpoints (Sudah Diimplementasikan)


## 1. Statistik Form

`GET /api/forms/{formId}/analytics?page=1&pageSize=20&search=john`

**Headers:** `Authorization: Bearer <token>` (pemilik form)

Menampilkan statistik lengkap form: total responden, skor tiap responden, rata-rata skor, detail jawaban.

**Query params (semua opsional):**
| Param | Keterangan |
|-------|------------|
| `page`, `pageSize` | Pagination responden di level database. Tanpa keduanya → semua responden dikirim (backward-compat). |
| `search` | Filter nama responden (nama akun login atau nama guest), case-insensitive `contains`. |

**Response 200 (dengan pagination):**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "totalResponses": 10,
    "totalQuestions": 5,
    "scorableQuestions": 3,
    "averageScore": 83.3,
    "respondents": [
      {
        "responseId": 1,
        "respondentName": "John Doe",
        "submittedAt": "2026-07-30T10:30:00Z",
        "answeredCount": 5,
        "totalQuestions": 5,
        "correctCount": 3,
        "scorableQuestions": 3,
        "score": 100.0,
        "answers": [
          {
            "questionId": 1,
            "question": "Apa warna langit?",
            "questionFormat": "text",
            "typeId": 1,
            "answerText": "Biru",
            "correctAnswer": "Biru",
            "isCorrect": true
          }
        ]
      }
    ],
    "page": 1,
    "pageSize": 20
  }
}
```

**Penjelasan:**
- `scorableQuestions` = jumlah soal yang memiliki kunci jawaban (CorrectAnswer atau opsi dengan IsCorrect)
- `score` = `correctCount / scorableQuestions * 100`, null jika tidak ada soal yang bisa diskor
- `averageScore` = rata-rata skor **semua** responden (tidak terpengaruh filter search/pagination)
- `isCorrect` = `true`/`false` untuk soal yang bisa diskor, `null` untuk soal survey
- Pagination & pencarian dieksekusi di database; hanya halaman aktif yang dimuat lengkap dengan jawabannya

---

