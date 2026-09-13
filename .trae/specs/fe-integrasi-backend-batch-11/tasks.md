# FormUp FE Integrasi Backend Batch 11 — Implementation Plan

Urutan pengerjaan: A-1 → A-2 → B-1 → B-2 → C-1 → C-2 → D-1 → Global Verify
(Sesuai prioritas tertinggi ke terendah, menghindari konflik edit file tumpang tindih.)

---

## Task 1: A-1 — Wrapper Fetch Interceptor Auto-Refresh Token (Mutex Pattern)
- **Status**: `pending`
- **Priority**: high
- **Depends On**: None
- **Description**:
  - Di `apiService.js`, bikin 1 layer wrapper `async function apiCall(url, options)` TERBARU yang
    memwrap semua request authenticated (gantikan pattern `fetch(..., headers: authHeaders())`
    yang tersebar).
  - Deteksi 401 dengan header `Token-Expired: true`.
  - Mutex / `isRefreshing` flag + `refreshPromise` queue untuk menghindari refresh ganda saat
    request paralel.
  - Kalau refresh berhasil → retry request asli 1x. Kalau refresh gagal → clear token + redirect ke `/login?reason=expired` + banner pesan.
  - Pastikan SEMUA call existing di komponen tetap BACKWARD COMPATIBLE (kalau tidak langsung ganti semua call sekarang, bisa. Kalau effort tinggi, minimal paksa semua call authenticated lewat wrapper).
- **Acceptance Criteria Addressed**: AC-A1.1, AC-A1.2, AC-A1.3
- **Test Requirements**:
  - `rule` TR-1.1: Diberikan token expired di localStorage, call 1x `saveQuestions(formId, qs).then()` → Network Tab DevTools memperlihatkan urutan: endpoint-call → 401 → /auth/refresh 1x → retry endpoint-call → 200. Evidence: screenshot Network.
  - `rule` TR-1.2: /auth/refresh mock return 401 → localStorage.formup_token dihapus + location.pathname = '/login' + ada pesan banner toast/bener muncul. Evidence: screenshot login page.
  - `rule` TR-1.3: Luncurkan Promise.all([call1, call2, call3, call4, call5]) saat token expired → tepat 1 request ke /auth/refresh (bukan 5). Evidence: hitung jumlah /auth/refresh di Network Tab = 1.
  - `rubric` TR-1.4: Transparansi ke caller. Scale 1-5. Anchors: 1=caller wajib handle error tambahan, 3=caller tetap tapi wrapper otomatis tapi fungsi berubah signature, 5=signature call sama persis, caller tidak tahu apa apa. Threshold >= 4. Evidence: diff apiService.js.
- **Notes**: Simpan minimal di `apiService.js` saja. JANGAN sampai merusak function export existing yang sudah work (misal upload image progress XHR TIDAK perlu lewat wrapper fetch vanilla; upload bisa tetap XHR langsung, cukup check 401 tanpa retry).

---

## Task 2: A-2 — UI Import Soal dari File (5 Format)
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 1 (optional — supaya saat upload & preview import, token expired tidak bikin import gagal. Tapi karena Task 2 bisa jalan tanpa Task 1, maka optional. Rekomendasi: Task 1 selesai dulu.)
- **Description**:
  - Buat file baru `ImportQuestionsModal.jsx` di folder src/components/ui/ atau src/features/form-builder/ (tanya: pilih path sesuai pola komponen lain).
  - Modal punya file input `accept=".xlsx,.xls,.csv,.pdf,.docx"`, area drag-drop minimal.
  - Link download Template: panggil `GET api/templates/import-questions?format=xlsx` (url dari apiService.js:533) sebagai href `<a href>` biasa download. Kalau endpoint return 404, sembunyikan link.
  - Pilih file → loading → POST `/import/preview` dengan FormData. Loading spinner "Sedang memproses file...".
  - Render ringkasan: total baris, berhasil, error.
  - Tabel preview 100 soal pertama. Baris error: background merah + pesan.
  - Tombol "Import Sekarang": enabled hanya jika `canImport=true`. Kalau `blocked=true`: disabled + pesan merah.
  - Commit: POST `/import`, berhasil → close modal → trigger `refreshFormQuestions()` (panggil ulang `getAllQuestions()` + set state builder) + toast sukses.
  - Pasang tombol trigger buka modal di Form Builder toolbar.
- **Acceptance Criteria Addressed**: AC-A2.1, AC-A2.2, AC-A2.3
- **Test Requirements**:
  - `rule` TR-2.1: Alur import file Excel lengkap (preview error + commit sukses) selesai: soal muncul di builder tanpa reload page. Evidence: 3 screenshot step; modal preview error + builder after import + toast sukses.
  - `rule` TR-2.2: PDF/DOCX minimal salah satu format non-Excel sukses di import. Evidence: pilih file PDF/DOCX → preview table ada → commit berhasil.
  - `rule` TR-2.3: Buka form yang sudah ada 1 responden → pilih file valid → preview blocked=true → tombol disabled + pesan merah muncul. Evidence: screenshot modal import.
  - `rubric` TR-2.4: Kualitas UX modal import. Scale 1-5. Anchors: 1=no progress, loading tidak jelas. 3=loading ada, error baris ditandai warna. 5=drag drop area, progress bar step, preview gambar soal image data URI tampil, count error jelas. Threshold>=3. Evidence: screenshot modal.
- **Notes**: Gunakan komponen Modal pattern yang SAMA dengan AIGeneratorModal.jsx (wrapper backdrop, close X, z-index). Jangan buat pattern modal baru.

---

## Task 3: B-1 — Input Bobot Poin Points per Soal + Total Maksimal Skor
- **Status**: `pending`
- **Priority**: high
- **Depends On**: None
- **Description**:
  - Edit `FormBuilder.jsx`: di tiap QuestionCard (card soal), tambahkan `<input type="number" min="0" step="1" value={q.points ?? 1} onChange={...} />` dengan label "Bobot Poin". Posisi: di samping Required toggle "Wajib diisi" atau di bagian header card.
  - State question array di FormBuilder state set `points: value`. Pastikan null/undefined → default 1.
  - Saat bulk save `saveQuestions()`: payload q.points ikut dikirim (camelCase points, sesuai policy JSON Program.cs camelCase).
  - Tambahkan element text di area summary header Form Builder: "Total Maksimal Skor: <span className="font-bold">{sumPoints}</span> poin". Live update setiap state questions berubah.
- **Acceptance Criteria Addressed**: AC-B1.1, AC-B1.2
- **Test Requirements**:
  - `rule` TR-3.1: 3 soal (2 pts, 3 pts, 5 pts). Simpan PUT /questions → Reload F5. Nilai bobot tiap soal TETAP. Total skor = 10. Evidence: before/after F5 screenshot.
  - `rule` TR-3.2: Submit 1 responden (soal 1 benar, soal 2 salah, soal 3 essay 0 / override blm). Skor total response = 2/10*100=20 (bukan 33.3). Evidence: halaman hasil skor responden.
  - `rubric` TR-3.3: Posisi input Points tidak mengganggu layout card soal. Scale 1-5. Anchors:1=hancurkan layout, 3=lumayan, 5=satu baris dengan toggle Wajib diisi. Threshold>=3. Evidence: screenshot card soal.
- **Notes**: Default points = 1. Jangan default 0, nanti user lupa isi → skor jadi 0 melulu.

---

## Task 4: B-2 — UI Manual Scoring Essay di Detail Responden
- **Status**: `pending`
- **Priority**: high
- **Depends On**: None
- **Description**:
  - Cari halaman/tempat render jawaban detail 1 responden (cari komponen dengan getResponseDetail / getResponseResult di FormResponsesPage.jsx expand row atau page detail terpisah).
  - Untuk tiap soal Essay (TypeId=1 / typeName=Essay), DI BAWAH jawaban responden, tambahkan DIV panel koreksi:
    * Input number (0 - 1000) Manual Score
    * Checkbox "Tandai jawaban ini benar (Override)"
    * Textarea Catatan ke siswa (opsional)
    * Tombol Simpan Koreksi
  - Default input diisi dari response a.ManualScore / a.IsCorrectOverride / a.OverrideNote dari GET detail (jika tidak null).
  - Tombol panggil updateAnswerScore (responseId, answerId, payload { ManualScore, IsCorrectOverride, OverrideNote }) function di apiService.js:632.
  - Sukses: trigger re-fetch `getResponseResult(formId, responseId) agar skor total di header berubah, tampilkan toast sukses.
- **Acceptance Criteria Addressed**: AC-B2.1
- **Test Requirements**:
  - `rule` TR-4.1: Isi skor manual essay 4 poin (dari bobot 5), override benar, catatan. Simpan. Reload. Semua value persisted. Skor total = 60 (dari skenario B1.2). Evidence: screenshot panel + skor header.
  - `rubric` TR-4.2: Konsistensi UI panel. Scale 1-5. 1=sulit dibedakan PG/Essay. 3=panel bisa dipakai. 5=panel punya background abu beda, border, mudah ditemukan. Threshold>=3. Evidence: screenshot panel.
- **Notes**: Kalau soal BUKAN Essay, panel tidak muncul. Jangan tampil scoring untuk PG/BenarSalah dll.

---

## Task 5: C-1 — Tombol Kosongkan Semua Soal Form Builder
- **Status**: `pending`
- **Priority**: medium
- **Depends On**: None
- **Description**:
  - Di Form Builder, cari tempat toolbar aksi (header) tambahkan "Aksi Lain" menu dropdown atau langsung tombol sekunder "Kosongkan Semua Soal".
  - Modal konfirmasi 2 langkah (minimal 2 tombol Batal dan Ya, Hapus). Kalau mudah tambahkan konfirmasi ketik nama form.
  - Ya → call `fetch DELETE /api/forms/{id}/questions` (buat function `deleteAllQuestions(formId)` di apiService.js kalau belum ada).
  - Sukses → set state questions = [] + toast + reset total skor = 0.
- **Acceptance Criteria Addressed**: AC-C1.1
- **Test Requirements**:
  - `rule` TR-5.1: 5 soal → klik delete all → confirm → 0 soal, reload F5 → 0 soal. Evidence: screenshot before & after.
  - `rubric` TR-5.2: Resiko rendah user tidak sengaja. Scale 1-5. 1=1 klik langsung, 2=konfirmasi 1 kali, 5=konfirmasi 2 langkah + harus ketik judul form. Threshold>=3. Evidence: screenshot dialog konfirmasi.

---

## Task 6: C-2 — Pagination + Search Soal Form Builder
- **Status**: `pending`
- **Priority**: medium
- **Depends On**: Task 2, Task 5 (karena aksi add/delete all soal harus reset pagination ke halaman 1)
- **Description**:
  - Modifikasi function `getAllQuestions(formId, { page, pageSize, search })` di apiService.js agar QUERY STRING ?page=X&pageSize=Y&search=Z di url (jika blm support — cek existing function).
  - Tambah state `currentPage, `pageSize (default 25), `searchTerm`.
  - Search box di atas soal: input debounced 250ms.
  - Pagination UI di bawah daftar: prev/next + tampil page 1/X. Total count soal per halaman 25; kalau count <=25, pagination UI hidden.
  - Setiap add soal baru via AI, import (Task 2), delete single / delete allTask 5): reset currentPage = 1 + reload list.
- **Acceptance Criteria Addressed**: AC-C2.1
- **Test Requirements**:
  - `rule` TR-6.1: 45 soal. Halaman 1 = 25 soal + pagination UI. Halaman 3=5 soal. Search "Termodinamika" → 5 soal 1 halaman pagination hilang. Evidence: 3 screenshot 3 state.
  - `rubric` TR-6.2: Performa load form banyak. Scale 1-5. 1=lag, 3=normal,5=cepat 1. Evidence: devtools performance waktu initial load.

---

## Task 7: D-1 — Verifikasi Export CSV/XLSX Include Kunci Jawaban & Bobot
- **Status**: `pending`
- **Priority**: low (Verifikasi, tidak implement kode FE baru)
- **Depends On**: Task 3 (butuh Points untuk skor berbobot agar bisa diverifikasi.)
- **Description**:
  - Jalankan manual steps:
    1. Buat form 3 soal (PG 2, 3 pts, Essay 5 pts) via Task 3.
    2. Isi 1 responden.
    3. Klik Export CSV. Simpan file.
    4. Klik Export XLSX. Simpan file.
    5. Buka kedua file di LibreOffice / Google Sheets.
    6. Cek: (a) Ada kolom kunci jawaban? Nama kolom = ? (b) Skor total responden: apakah = 20 ? (cocok TR-3.2 scenario)
  - Tulis hasil: LULUS / SEBAGIAN / GAGAL per setiap format.
  - Kalau GAGAL, catat temuan (misal, kolom tidak ada) ke tasks bagian "Temuan"). JANGAN ubah file apapun backend.
- **Acceptance Criteria Addressed**: AC-D1.1
- **Test Requirements**:
  - `rubric` TR-7.1: Rubric AC-D1.1. Scale 0-5. Anchors dan Threshold>=3. Evidence: 2 screenshot spreadsheet CSV/XLSX opened.

---

## Task 8: Global Smoke Test Fitur Existing Tidak Regresi
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 1-6 selesai semua)
- **Description**: Manual jalankan 5 smoke test. LULUS semua (100%):
  1. Login email/password (biasa berhasil.
  2. Exam Monitoring: Buka form exam ada 1 responden ujian → tombol Force Submit → status jadi force-submitted.
  3. AI Generator Modal: Generate 5 soal PG via AI sukses, soal muncul di builder.
  4. Export CSV Analytics: Download file CSV bisa diunduh.
  5. Buka link form public: Submit jawaban responden submit sukses (guest submit).
  6. Cek: Console tidak ada error merah fatal (warning boleh).
- **Acceptance Criteria Addressed**: AC-GLOBAL.2
- **Test Requirements**:
  - `rule` TR-8.1: 5/5 smoke test 100% lulus. Evidence: catatan checklist per item, screenshot bukti di tasks.md completion evidence.

---

## Task 9: Global Verify Zero Backend & Zero Mobile Change
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 1-8 selesai)
- **Description**: Run `git diff --name-only` / `git status`. Daftar file modified hanya di bawah `web/form-fe/src/**`.
  TIDAK ADA satupun file di `api/**` atau `mobile/**` yang berubah. Catat list semua file modified group per task.
- **Acceptance Criteria Addressed**: AC-GLOBAL.1
- **Test Requirements**:
  - `rule` TR-9.1: Diff name-only 100% di web/form-fe/src. Evidence: output command.
  - `rule` TR-9.2: Catat semua file modified dikelompok per Task (Task 1 ubah file A,B,C, Task2 ubah D,E, dst).

---

## Temuan / Issue / Bug / Gap Kontrak (Diisi selama Implementasi)

(Area ini untuk mengisi gap kontrak yang ditemukan TIDAK SESUAI ekspektasi spec. Jangan ubah backend; catat saja temuan disini beserta workarounds FE-only):

| ID | Kategori | Deskripsi | Workaround FE | Blocker? |
|---|---|---|---|---|
| (contoh) F-1 | Gap kontrak | Endpoint `/api/templates/import-questions return 404 | Link download Template disembunyikan saja, user tetap bisa upload | Tidak |
| | | | | |
