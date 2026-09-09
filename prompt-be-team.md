# Handoff Dokumen: Backend Requirements & Action Items (FormUp API)

Dokumen ini ditujukan untuk tim Backend FormUp (.NET / C# Controllers) untuk mengimplementasikan fitur-fitur dan perbaikan bug yang membutuhkan endpoint baru, perubahan DTO, atau penambahan kolom database.

---

## 1. Item A2: Respondent Name pada Admin Feedback Endpoint

### Status
🔴 **Blocked (Membutuhkan Perubahan Backend)**

### Masalah
Saat admin membuka tab Feedback / Umpan Balik (`GET /api/admin/feedback` atau `FeedbacksController.cs`), jika feedback terkait dengan pengisian respon formulir tertentu, response JSON saat ini tidak menyertakan identitas atau nama responden pengisi (`RespondentName`), sehingga di dashboard admin hanya tampil `Anonim` atau `User.FullName` pemilik form.

### Solusi Backend
Di `FeedbacksController.cs` pada method pengambilan daftar feedback (`GetAllFeedback` / `GetAdminFeedbacks`):
1. Lakukan `Include(f => f.Response)` atau join ke tabel `Responses`.
2. Map properti `RespondentName = feedback.Response != null ? feedback.Response.RespondentName : null` ke dalam DTO response feedback.
3. Response DTO Feedback yang diharapkan:
```json
{
  "id": 12,
  "formId": 45,
  "formTitle": "Kuis Matematika SMA",
  "userId": 3,
  "userName": "Budi Santoso",
  "userEmail": "budi@gmail.com",
  "respondentName": "Siti Rahmawati",
  "reason": "LAPORAN_SOAL_TIDAK_JELAS",
  "description": "Soal nomor 3 ada opsi ganda yang sama",
  "createdAt": "2026-09-09T10:00:00Z"
}
```

---

## 2. Item A5: Kolom Kunci Jawaban (`CorrectAnswer`) pada Export Respons CSV/XLSX

### Status
🔴 **Blocked (Membutuhkan Perubahan Backend)**

### Masalah
Saat pemilik form mengunduh data respons via `GET /api/forms/{id}/responses/export/csv` atau `GET /api/forms/{id}/responses/export/xlsx` di `AnalyticsController.cs` / `ResponsesController.cs`, file CSV/XLSX hanya menyertakan kolom identitas responden, skor, dan jawaban responden, tetapi **TIDAK menyertakan kolom Kunci Jawaban / Bobot Soal**.

### Solusi Backend
Di `AnalyticsController.cs` atau service export Excel/CSV (`ExportResponsesToCsv` / `ExportResponsesToXlsx`):
1. Query daftar pertanyaan form (`Questions`) beserta `CorrectAnswer` dan opsi `isCorrect: true`.
2. Tambahkan header kolom `Kunci Jawaban [Soal X]` atau sertakan baris referensi kunci di bagian atas/kolom terpisah file CSV/XLSX.
3. Format kolom header yang direkomendasikan:
   - `No`, `Nama Responden`, `Waktu Mulai`, `Waktu Selesai`, `Skor Akhir`
   - `[Soal 1] Teks Soal`, `[Kunci 1] Kunci Jawaban`, `[Jawaban 1] Jawaban Responden`, `[Status 1] Benar/Salah`

---

## 3. Item B12: Live Exam Monitoring & Proctoring API

### Status
🔴 **Blocked (Fitur Baru Backend)**

### Masalah
Frontend ujian FormUp membutuhkan dukungan backend untuk pemantauan ujian secara realtime:
1. Mengetahui siapa saja siswa yang sedang aktif mengerjakan ujian saat ini.
2. Memaksa submit peserta tertentu (Force Submit) jika terindikasi curang atau waktu habis.
3. Mereset attempt peserta (Kick / Reset Session) jika terjadi kendala teknis perangkat peserta.

### Solusi Backend (Endpoint Baru yang Dibutuhkan)

1. **`GET /api/forms/{formId}/exam/active-sessions`**
   - Mengembalikan daftar peserta yang sedang mengerjakan ujian secara realtime (berdasarkan event heartbeat / session token).
   - Response DTO:
     ```json
     [
       {
         "sessionId": "sess_abc123",
         "respondentName": "Ahmad Dani",
         "startedAt": "2026-09-09T10:15:00Z",
         "timeLeftSeconds": 1420,
         "tabSwitchCount": 3,
         "answeredCount": 8,
         "totalQuestions": 20
       }
     ]
     ```

2. **`POST /api/forms/{formId}/exam/sessions/{sessionId}/force-submit`**
   - Menghentikan paksa sesi ujian peserta dan menandai status respons menjadi `SubmittedByProctor` dengan jawaban yang telah tersimpan sampai saat itu.

3. **`POST /api/forms/{formId}/exam/sessions/{sessionId}/reset`**
   - Mereset status sesi ujian agar peserta dapat login/memulai kembali pengerjaan dari awal.

---

Dokumen ini disusun untuk melengkapi Sprint FE-Only FormUp. Semua perubahan frontend yang kompatibel telah diselesaikan.
