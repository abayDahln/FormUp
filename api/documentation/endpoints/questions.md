# Question Endpoints (Sudah Diimplementasikan)


> **Aturan mutasi soal:** soal boleh diedit selama form belum punya respons apa pun — termasuk form berstatus `published`. Jika sudah ada minimal 1 respon, semua mutasi soal ditolak `400 Soal tidak dapat diubah karena form sudah memiliki respons` (menjaga konsistensi data jawaban). Form `published` yang kehabisan soal otomatis kembali ke status `draft`.

## 1. Daftar Pertanyaan

`GET /api/forms/{formId}/questions`

**Headers:** `Authorization: Bearer <token>`

Diakses oleh **pemilik form** atau **admin** (role `ADMIN`).

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    {
      "id": 1,
      "formId": 1,
      "typeId": 1,
      "question": "Apa pendapat Anda?",
      "questionFormat": "text",
      "questionOrder": 1,
      "isRequired": true,
      "options": [
        { "id": 1, "optionText": "Sangat Puas", "isCorrect": false, "optionOrder": 1 }
      ],
      "createdAt": "...",
      "updatedAt": "..."
    }
  ]
}
```

---

## 2. Simpan Questions

`POST /api/forms/{formId}/questions`

**Headers:** `Authorization: Bearer <token>`

Buat soal + opsi sekaligus dalam 1 request.

**Request:** `question` bisa plain text atau Delta JSON (Quill) untuk teks berformat. `questionFormat` opsional (dideteksi otomatis dari isi). Soal yang diawali `[` harus Delta JSON valid, jika tidak → `400`.
```json
{
  "questions": [
    {
      "typeId": 1,
      "question": "Apa warna langit?",
      "isRequired": true,
      "options": [
        { "optionText": "Biru", "isCorrect": true },
        { "optionText": "Hijau", "isCorrect": false }
      ]
    },
    {
      "typeId": 3,
      "question": "2+2 berapa?",
      "isRequired": true,
      "correctAnswer": "4"
    }
  ]
}
```

**Contoh pertanyaan berformat (Delta JSON):**
```json
{
  "typeId": 1,
  "question": "[{\"insert\":\"Apa warna \",\"attributes\":{\"italic\":true}},{\"insert\":\"langit\",\"attributes\":{\"bold\":true}},{\"insert\":\"?\\n\"}]",
  "isRequired": true
}
```
Pada respons, `questionFormat` akan bernilai `delta`.

**Response 201:** Array questions dengan ID masing-masing.

---

## 3. Simpan / Update Questions

`PUT /api/forms/{formId}/questions`

**Headers:** `Authorization: Bearer <token>`

Update soal **in-place** (bukan replace-all lagi). Setiap item boleh membawa `id`:
- Item dengan `id` yang cocok dengan soal aktif → soal **di-update** (teks, tipe, order, opsi, dsb).
- Item tanpa `id` → soal **baru** dibuat.
- Soal aktif yang **tidak ada** di payload → di-soft-delete.

Opsi selalu diganti utuh per soal (hapus lama, buat ulang dari `options`).

**Request:** `questionFormat` opsional (dideteksi otomatis dari isi); `question` diawali `[` harus Delta JSON valid, jika tidak → `400`.
```json
{
  "questions": [
    {
      "id": 1,
      "typeId": 1,
      "question": "Apa warna langit? (diubah)",
      "questionFormat": "text",
      "isRequired": true,
      "options": [
        { "optionText": "Biru", "isCorrect": true },
        { "optionText": "Ungu", "isCorrect": false }
      ]
    },
    {
      "typeId": 3,
      "question": "2+2 berapa? (soal baru)",
      "isRequired": true,
      "correctAnswer": "4"
    }
  ]
}
```

**Response 200:** Array questions aktif setelah save (dengan ID masing-masing).

**Catatan:** Karena update in-place, `questionId` pada response lama tetap valid — analitik & export tidak kehilangan history saat soal diedit.

---

## 4. Hapus Pertanyaan

`DELETE /api/forms/{formId}/questions/{id}`

**Headers:** `Authorization: Bearer <token>`

Soft delete satu pertanyaan beserta opsi-nya. Hanya pemilik form.

**Response 200:**
```json
{
  "status": 200,
  "message": "Question deleted"
}
```

---

## 5. Upload Image Question

`POST /api/forms/{formId}/questions/{id}/upload-image`

**Headers:** `Authorization: Bearer <token>`

**Content-Type:** `multipart/form-data` — kirim file dengan key `file`

Upload & langsung set `questionImage` ke question ID tersebut. File lama otomatis dihapus.

| Aturan | Nilai |
|--------|-------|
| Format | JPG, PNG, GIF, WebP |
| Max size | 10 MB |
| Lokasi | `wwwroot/questions/images/{guid}.ext` |

**Response 200:**
```json
{
  "status": 200,
  "message": "Image uploaded",
  "data": { "questionImage": "/questions/images/xxx.jpg" }
}
```

---

## 6. Upload Audio Question

`POST /api/forms/{formId}/questions/{id}/upload-audio`

**Headers:** `Authorization: Bearer <token>`

**Content-Type:** `multipart/form-data` — kirim file dengan key `file`

Upload audio untuk soal. File lama otomatis dihapus.

| Aturan | Nilai |
|--------|-------|
| Format | MP3, WAV, OGG, M4A, AAC, WebM |
| Max size | 20 MB |
| Lokasi | `wwwroot/questions/audio/{guid}.ext` |

**Response 200:**
```json
{
  "status": 200,
  "message": "Audio uploaded",
  "data": { "questionAudio": "/questions/audio/xxx.mp3" }
}
```

---

## 7. Import Soal dari File

`POST /api/forms/{formId}/questions/import`

**Headers:** `Authorization: Bearer <token>`

**Content-Type:** `multipart/form-data`

Kirim file dengan key `file`.

| Aturan | Nilai |
|--------|-------|
| Format | `.xlsx`, `.xls`, `.csv`, `.pdf`, `.docx` |
| Max size | 5 MB |

**Format CSV / Excel (baris pertama = header):**

| Header | Required | Default | Keterangan |
|--------|----------|---------|-----------|
| `question` | Ya | — | Teks pertanyaan |
| `type_id` | Tidak | 1 | ID tipe pertanyaan (lihat tabel QuestionType) |
| `order` | Tidak | auto | Urutan pertanyaan |
| `is_required` | Tidak | FALSE | `TRUE` / `FALSE` |
| `randomize_options` | Tidak | FALSE | `TRUE` / `FALSE` |
| `correct_answer` | Tidak | — | Jawaban benar (untuk quiz) |
| `options` | Tidak | — | Opsi dipisah pipe: `Opsi A\|Opsi B\|Opsi C` |

**Contoh isi CSV:**
```csv
question,type_id,order,is_required,options
Apa warna langit?,1,1,TRUE,Biru|Hijau|Merah
2+2 berapa?,3,2,TRUE,
```

**Format PDF / DOCX:**

Setiap soal dipisah oleh baris kosong. Format metadata:

```
Question: Apa warna langit?
Options: Biru | Hijau | Merah
Type ID: 1
Is Required: true
```

Atau opsi bisa ditulis per baris dengan awalan `- `:
```
Apa warna langit?
- Biru
- Hijau
- Merah
type_id: 1
```

**Template download:** `GET /api/templates/import-questions?format=csv` (lihat bagian Template Endpoints)

Impor terdiri dari **2 langkah terpisah**:

### 7a. Preview Import (parse & validasi saja, TIDAK menyimpan)

`POST /api/forms/{formId}/questions/import/preview`

**Response 200:**
```json
{
  "status": 200,
  "message": "Preview ready",
  "data": {
    "preview": true,
    "blocked": false,
    "totalRows": 5,
    "totalQuestions": 4,
    "skippedCount": 1,
    "canImport": true,
    "errors": [
      { "rowNumber": 3, "field": "type_id", "message": "type_id '9' tidak dikenal (1=Essay, 2=Multiple Choice, 3=Checkbox, 4=Date Time, 5=True False)" }
    ],
    "questions": [
      {
        "order": 1,
        "rowNumber": 2,
        "question": "Apa warna langit?",
        "typeId": 1,
        "isRequired": true,
        "optionsCount": 3,
        "options": ["A. Biru", "B. Hijau", "C. Merah"],
        "hasCorrectAnswer": false,
        "hasImage": false,
        "image": null
      }
    ]
  }
}
```

- `errors` berisi daftar kesalahan format per baris (`rowNumber`, `field`, `message`) — baris ini akan dilewati saat impor.
- `blocked = true` → form sudah punya respons, impor ditolak.
- `startNumber` = nomor pertama hasil impor; **nomor soal impor selalu lanjut setelah semua soal yang sudah ada** di form (kolom `order` pada file bersifat relatif dan di-offset).
- `image` berisi data URI base64 (`data:image/png;base64,...`) dari gambar yang terekstrak dokumen — bisa langsung ditampilkan client tanpa request tambahan. `null` jika gambar >1,5 MB atau tidak ada.
- Tipe file dideteksi dari **isi file**, bukan nama/ekstensi — file dari Google Drive bernama `soal` (tanpa ekstensi) atau `soal.docx.docx` tetap terbaca dengan benar.
- Jika seluruh baris tidak valid atau header kolom tidak sesuai → `400` dengan pesan spesifik (mis. kolom `question` tidak ditemukan).

### 7b. Save Import (simpan ke database)

`POST /api/forms/{formId}/questions/import`

Panggil setelah user konfirmasi hasil preview.

**Response 200:**
```json
{
  "status": 200,
  "message": "3 questions imported",
  "data": {
    "totalImported": 3,
    "totalSkipped": 1,
    "errors": ["Baris 3 (type_id): type_id '9' tidak dikenal (1=Essay, ...)"]
  }
}
```

**Response 400** jika tidak ada satu pun baris valid:
```json
{
  "status": 400,
  "message": "Tidak ada soal valid yang bisa diimpor dari file",
  "data": {
    "totalImported": 0,
    "totalSkipped": 5,
    "errors": [ ... ]
  }
}
```

---

