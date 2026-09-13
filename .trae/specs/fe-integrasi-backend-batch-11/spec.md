# FormUp FE Integrasi Backend Batch 11 — Product Requirements Document

## Overview
- **Summary**: Integrasikan 6 kelompok fitur backend (yang sudah selesai & siap pakai) ke frontend web FormUp, selama ini "terkubur" karena tidak ada UI atau interceptor. Fokus Batch 11 ini:
  - A-1 Auto refresh token interceptor (mencegah kehilangan data edit form akibat JWT kedaluwarsa)
  - A-2 UI Import soal dari file Excel/CSV/PDF/DOCX (fitur terbesar yang BE sudah siap)
  - B-1 Input bobot `Points` per soal di Form Builder (unlock skor berbobot di analytics)
  - B-2 UI manual scoring + override benar/salah + catatan untuk soal essay
  - C-1 Tombol "Kosongkan Semua Soal" 1 klik di Form Builder
  - C-2 Pagination + search di daftar soal Form Builder (form 100+ soal tidak lag)
  - D-1 Verifikasi export CSV/XLSX sudah otomatis sertakan kolom kunci jawaban & bobot
- **Purpose**: Membuka akses user ke fitur backend premium yang sudah dibangun tapi
  tidak bisa dipakai, sambil menutup risiko hilangnya data akibat token expired.
- **Target Users**: Pemilik form (guru/dosen/admin sekolah) yang membuat form/kuis
  dan memproses respons di dashboard FormUp web.

## Goals
- G-1: Mengeliminasi risiko hilangnya data edit form akibat token JWT expire di
  tengah pengerjaan (zero data-loss scenario untuk sesi edit panjang > 1 jam).
- G-2: Membuka 100% akses ke fitur import multi-format soal yang sudah dibangun
  BE (Excel/CSV/PDF/DOCX), sehingga user (guru) tidak perlu input 50+ soal
  manual dan bisa memanfaatkan dokumen soal yang sudah ada.
- G-3: Unlock perhitungan skor berbobot (custom Points per soal) yang logikanya
  SUDAH berjalan di Analytics/Export BE, cuma belum ada UI input.
- G-4: Membuka koreksi essay manual (scoring override + catatan per jawaban)
  yang endpoint BE siap, sehingga guru tidak perlu pakai tools luar (spreadsheet)
  untuk koreksi manual.
- G-5: Meningkatkan produktivitas di Form Builder: 1 klik hapus semua soal
  (C-1) dan tidak ada lag untuk form 100+ soal (C-2 pagination).
- G-6: Memastikan tanpa perubahan backend dan tanpa perubahan mobile app sama
  sekali sesuai constraint.

## Non-Goals
- NG-1: **Tidak mengubah / menambah endpoint backend.** Semua kontrak API sudah
  final di 18 file `.cs` yang berubah; task hanya integrasi di FE. Kalau ada gap
  kontrak dilaporkan sebagai temuan, tidak ditambal di BE.
- NG-2: **Tidak menyentuh kode mobile app** (Flutter di `/mobile`). Semua scope
  murni `web/form-fe/`.
- NG-3: **Tidak merubah / refactor fitur yang sudah terintegrasi baik**: OTP
  Register (2-step), attempt history responden, Exam Monitoring live dashboard
  proctoring (force-submit / reset / sessions list), heartbeat exam-events,
  ReferenceCache (transparan ke FE), rate limiting policy.
- NG-4: Tidak merancang UI dari nol (full redesign). UI tambahan harus
  konsisten dengan style/komponen yang sudah ada di app (Tailwind, modal
  pakai pattern yang sama, dll).
- NG-5: Tidak menambah fitur AI di batch ini (smart scoring essay, AI parse
  import, dll) — AI import soal sudah diserahkan ke backend import parser
  (ParseStructuredEntries), FE hanya upload file.

## Background & Context
Dari audit diff 18 file backend (dokumen task Batch 11), ditemukan 6 kelompok
fitur backend siap pakai tapi status integrasi FE tidak merata:

| Fitur | Endpoint BE | Status FE Sebelum Integrasi |
|---|---|---|
| Refresh token 401 interceptor | `POST /api/auth/refresh` | function `refreshToken()` ada di `apiService.js:98`, **TIDAK PERNAH dipanggil otomatis** (tidak ada interceptor fetch wrapper) |
| Import soal preview & commit | `/questions/import/preview`, `/questions/import` | function `importQuestions()` ada di `apiService.js:257`, **TIDAK ADA UI trigger** (tidak ada tombol upload) |
| Points (bobot per soal) | Field `Points` di GET/PUT/POST `/questions` | BE simpan & hitung analytics **benar**, **TIDAK ADA input field Points di Form Builder** |
| Override skor essay + catatan | `PUT /responses/{id}/answers/{aid}/score`, `PUT /responses/{id}/scores` | function `updateAnswerScore()` ada di `apiService.js:632`, **TIDAK ADA UI** di halaman Detail Responden |
| Delete ALL questions 1 request | `DELETE /api/forms/{id}/questions` | BE endpoint siap, **TIDAK ADA UI tombol** di Form Builder |
| Pagination + search daftar soal | `GET /forms/{id}/questions?page=&pageSize=&search=` | BE support query param, FE Form Builder **masih load SEMUA soal tanpa pagination** |
| Export CSV/XLSX kunci jawaban & bobot | Endpoints export di `AnalyticsController` | BE kemungkinan SUDAH include (diff 31 baris Analytics + Points counting), **perlu diverifikasi manual** (D-1) tanpa perubahan FE. |

Bukti file yang diperiksa (berdasarkan audit sebelum Batch 11):
- `api/Controllers/AuthController.cs:146` + `Program.cs:127-136` (Token-Expired header policy)
- `api/Controllers/QuestionsController.cs:415-460` (DeleteAll) + `:462-648` (import preview & commit)
- `api/Controllers/ResponsesController.cs:291-349` (scoring override essay)
- `web/form-fe/src/services/apiService.js` (semua function endpoint FE yang sudah ada tapi tidak terpakai)

## Functional Requirements

### Bagian A (Prioritas Tertinggi)

**FR-A1: Wrapper Fetch Interceptor untuk Auto Refresh Token + Retry**
- FR-A1-1: Semua request API yang membutuhkan header Authorization Bearer TIDAK
  langsung memanggil `fetch()` mentah. Dilewatkan 1 layer wrapper terpusat di
  `apiService.js` (hanya 1 tempat interception).
- FR-A1-2: Saat sebuah request mengembalikan status 401 dan response header
  `Token-Expired: true` (atau setidaknya status 401 Unauthorized sesuai
  kontrak `Program.cs:137-146`), wrapper otomatis:
  1. Memanggil `refreshToken()` (yang sudah ada di `apiService.js:98`) HANYA
     SEKALI meskipun banyak request paralel gagal bersamaan (race condition
     proteksi / mutex pattern).
  2. Jika refresh berhasil: `setToken(tokenBaru)`, ulangi request ASLI yang
     gagal tadi (dengan headers + body yang sama) 1 kali, kembalikan hasil ke
     caller secara transparan (caller tidak tahu ada proses refresh).
  3. Jika refresh GAGAL (return 401 juga): hapus token dari storage, redirect
     user ke halaman `/login` DENGAN query parameter `?reason=session_expired`
     atau pesan toast "Sesi Anda berakhir, silakan login kembali" (JANGAN
     silent redirect tanpa penjelasan user).
- FR-A1-3: Kalau sebuah request sedang "menunggu refresh selesai" karena ada
  request lain yang lagi refresh, request tersebut ikut pakai token baru
  yang sama setelah refresh berhasil (antrian / promise queue pattern).

**FR-A2: UI Import Soal dari File (5 Format)**
- FR-A2-1: Di halaman Form Builder, muncul tombol **"Import Soal dari File"**
  yang posisinya dekat area aksi tambah soal (contoh: sebelah tombol "+ Tambah
  Soal" atau di toolbar atas daftar soal). Tombol hanya muncul ketika user
  sedang di mode edit form.
- FR-A2-2: Klik tombol membuka modal upload dengan:
  1. File picker `<input type="file">` yang `accept=".xlsx,.xls,.csv,.pdf,.docx"`
     + tulisan "Dukungan format: Excel (.xlsx/.xls), CSV, PDF, Word (.docx).
     Maksimal 5 MB per file" (sesuai batas BE `FileValidation.MaxImportBytes`).
  2. Link atau tombol "Download Template Excel" yang mengarah ke endpoint
     yang SUDAH ADA di `apiService.js:533`:
     `/api/templates/import-questions?format=xlsx` (bila BE punya format lain
     seperti csv, sediakan juga).
  3. Drag & drop area opsional (bila tidak butuh usaha besar) — minimal
     file picker standar WAJIB ADA.
- FR-A2-3: Setelah file dipilih, FE otomatis panggil endpoint **PREVIEW**
  (`POST /import/preview`) BUKAN endpoint commit. Sambil menampilkan
  **progress indicator / loading spinner teks "Sedang memproses file..."**
  (penting untuk PDF/DOCX yang parsingnya agak lama).
- FR-A2-4: Ketika preview sudah kembali, modal menampilkan **Ringkasan**:
  - `Total baris dibaca: XX`
  - `Berhasil diparsing: YY soal`
  - `Error: ZZ baris`
  - Daftar 100 soal pertama (sesuai batas BE preview) dalam tabel:
    nomor soal (startNumber + index), teks soal, tipe, jumlah opsi, apakah
    ada kunci jawaban (`hasCorrectAnswer`), preview gambar jika ada (`image`
    data URI dari BE response `preview.image`).
- FR-A2-5: Baris yang ERROR (berdasarkan `errors[]` dari response preview)
  DITANDAI jelas: background merah muda / badge merah di baris, dengan
  pesan error: `Baris {rowNumber} — Kolom {field}: {message}` persis seperti
  yang dikembalikan BE. User jadi tahu baris mana yang perlu diperbaiki di
  file aslinya sebelum import ulang.
- FR-A2-6: Tombol **"Import Sekarang (YY soal)"** di modal. Tombol HANYA AKTIF
  bila `canImport === true` dari response preview (setidaknya ada 1 soal
  valid dan form belum punya responden). Kalau `blocked === true` karena
  form sudah ada responden → tampilkan peringatan di atas tombol: "Form
  sudah memiliki responden; soal tidak bisa ditambahkan via impor. Buat
  salinan form untuk menambah soal." tombol disabled.
- FR-A2-7: Klik "Import Sekarang" memanggil endpoint COMMIT (`/import`),
  sekali lagi dengan progress indicator, bila BERHASIL:
  1. Tutup modal
  2. Refresh state `questions` di Form Builder dengan memanggil ulang
     `getAllQuestions(formId)` agar soal baru langsung muncul tanpa reload
     halaman.
  3. Munculkan toast sukses: "✅ Berhasil mengimpor YY soal. ZZ baris dilewati
     karena error."
- FR-A2-8: Bila di tengah PREVIEW atau COMMIT terjadi error (misal file >5MB,
  parsing gagal total), modal menampilkan error message persis dari BE
  response `message`, JANGAN di generikkan.

### Bagian B (Prioritas Tinggi)

**FR-B1: Input Bobot Poin per Soal (Points) + Total Bobot Form**
- FR-B1-1: Di setiap card edit soal (Form Builder), tambahkan input angka
  integer dengan label **"Bobot Poin"** (misal di bawah field "Wajib diisi"
  atau di samping judul header tiap card soal).
- FR-B1-2: Default value untuk soal baru = `1` (sesuai behavior BE default —
  `AnalyticsController.cs:222`). Untuk soal yang sudah ada sebelumnya yang
  field `Points` null/undefined → FE anggap = 1 (tampilkan sebagai 1).
- FR-B1-3: Nilai `Points` diseragamkan sebagai integer non-negative. Tidak
  perlu validasi range ekstrem (validasi final di BE cukup); FE hanya
  memastikan tidak bisa input < 0 (min=0).
- FR-B1-4: Saat save soal via `PUT /forms/{id}/questions` (bulk save),
  field `points` (lowercase camelCase sesuai FE serialize) ikut dikirim
  BERSAMA data soal lainnya, persis pada item Question.
- FR-B1-5: Di area header Form Builder (atau tab "Publikasikan" / area
  summary), ditampilkan info **"Total Maksimal Skor: XX poin"** di mana
  XX = jumlah seluruh `Points` dari soal aktif, LIVE update setiap kali
  user mengubah bobot / menambah / menghapus soal.

**FR-B2: UI Manual Scoring Essay di Halaman Detail Responden**
- FR-B2-1: Di halaman Detail Responden (tempat guru melihat jawaban 1 siswa
  lengkap), untuk SETIAP soal tipe **Essay** (TypeId 1, atau nama type
  "Essay" sesuai `apiService.js:355` resolve helper `resolveAnswerKey`),
  muncul panel koreksi tambahan DI BAWAH teks jawaban responden.
- FR-B2-2: Panel koreksi berisi 3 input + tombol simpan:
  1. `Input angka Skor Manual (0-1000)` → bind ke `ManualScore`
     (validasi FE: min 0, max 1000, sesuai BE check
     `ResponsesController.cs:308`).
  2. `Toggle/checkbox Override: [ ] Tandai jawaban ini benar (meskipun
     jawaban tidak match otomatis)` → bind ke `IsCorrectOverride`.
  3. `Textarea Catatan ke siswa (opsional)` → bind ke `OverrideNote`.
  4. Tombol **"Simpan Koreksi"** yang disabled kalau tidak ada perubahan
     dari state terakhir, enabled kalau ada dirty.
- FR-B2-3: Tombol simpan memanggil `updateAnswerScore(responseId, answerId,
  { ManualScore, IsCorrectOverride, OverrideNote })` (function yang sudah
  ada di `apiService.js:632-634`).
- FR-B2-4: Setelah simpan BERHASIL, field skor TOTAL responden di header
  halaman detail (jika ada) DIHITUNG ULANG — minimal trigger refresh GET
  detail lagi `getResponseDetail()` atau `getResponseResult()` agar angka
  skor total berubah sesuai koreksi manual terbaru. Muncul toast:
  "✅ Koreksi jawaban disimpan".
- FR-B2-5: Jika sebuah jawaban essay SEBELUMNYA sudah dikoreksi (value
  `ManualScore / IsCorrectOverride / OverrideNote` di GET response detail
  TIDAK null/undefined), maka nilai tersebut TAMPILKAN SEBAGAI DEFAULT di
  input saat pertama kali halaman render (tidak hilang saat reload, dan
  user bisa edit untuk update).

### Bagian C (Prioritas Sedang)

**FR-C1: Tombol "Kosongkan Semua Soal" di Form Builder**
- FR-C1-1: Di Form Builder, sediakan tombol (mungkin di dalam menu titik 3
  "Aksi Lain", atau di toolbar header) berlabel **"Kosongkan Semua Soal"**,
  berwarna abu/merah sekunder (bukan tombol primer yang dominan).
- FR-C1-2: Klik tombol → muncul **Dialog Konfirmasi 2 langkah**:
  - Langkah 1: "⚠️ Anda akan menghapus SEMUA soal ({count} soal) dari form
    ini. Tindakan ini TIDAK BISA dibatalkan. Apakah Anda yakin?"
    tombol: [Batal] [Ya, Hapus Semua Soal (warning: perlu langkah 2)]
  - (Opsional tapi dianjurkan bila mudah): Minta user ketik **NAMA JUDUL
    FORM** persis di sebuah input sebelum tombol final enabled — untuk
    mencegah klik tidak sengaja — tapi minimal dialog 2 tombol.
- FR-C1-3: Konfirmasi → FE call `DELETE /api/forms/{id}/questions` (endpoint
  baru BE QuestionsController DELETE tanpa id).
- FR-C1-4: Berhasil → state questions di Form Builder di-set ke array kosong,
  total skor di reset ke 0, toast: "✅ Semua soal berhasil dihapus" —
  TANPA reload halaman manual.

**FR-C2: Pagination + Search di Daftar Soal Form Builder**
- FR-C2-1: DI ATAS daftar soal Form Builder, tambah search input dengan
  placeholder **"🔍 Cari teks soal..."**. Setiap ketikan (debounce 250ms)
  memicu ulang pemanggilan `getAllQuestions(formId, { search: value })`.
- FR-C2-2: Untuk form yang **jumlah soal > pageSize** (default pageSize =
  20, atau bisa hardcode 25), muncul pagination UI di BAWAH daftar soal
  (tombol Sebelumnya | Halaman 1/X | Berikutnya, atau infinite scroll —
  pilih yang paling konsisten dengan halaman lain seperti Form Responses
  list yang sudah punya pagination `page/pageSize` di `apiService.js:324`).
  Kalau semua soal masih muat 1 halaman (≤ pageSize): pagination UI tidak
  ditampilkan (tidak bikin kacau UX form kecil).
- FR-C2-3: Ketika user sedang search (ada text di search box) lalu pindah
  halaman, parameter `search` dipertahankan antar halaman (tetap filter
  search, tidak reset).
- FR-C2-4: Semua aksi state lain di Form Builder (tambah soal via AI,
  import file A-2, hapus soal 1 biji, hapus semua C-1) harus ME-reset
  pagination ke halaman pertama dan refresh ulang list agar sinkron.
- FR-C2-5: Fitur **drag-and-drop reorder soal** (jika sudah ada di batch
  sebelum atau sebentar lagi) bila terpengaruh pagination: saat user
  scroll halaman 2 & pindahkan soal, FE harus menyesuaikan QuestionOrder
  sesuai urutan hasil reorder (kalau ternyata drag-drop tidak
  kompatibel dengan pagination karena butuh list penuh, prioritaskan
  drag-drop untuk form kecil, dan untuk form > pageSize: non-aktifkan drag
  drop + beri pesan "Untuk menggunakan urut seret, matikan pagination
  dengan memperbesar pageSize" — atau solusi lain yang masuk akal.
  Default: asumsikan drag-drop tidak dipasang di batch ini, jadi C-2 hanya
  urus pagination + search, tidak konflik.)

### Bagian D (Verifikasi Saja, Tanpa Kode Baru)

**FR-D1: Verifikasi Export CSV/XLSX Sudah Include Kunci Jawaban & Bobot Poin**
- FR-D1-1: Menghasilkan 1 form ujian sederhana (minimal 2 soal PG + 1 soal
  essay) dengan Points yang berbeda (misal PG @2 poin, essay @5 poin)
  setelah B-1 terpasang, submit minimal 1 responden, lalu export CSV & XLSX
  dari tombol yang SUDAH ADA di halaman Analytics/Responses.
- FR-D1-2: Buka file export dengan spreadsheet editor, verifikasi:
  (a) Apakah ada 1 kolom yang isinya = KUNCI JAWABAN per soal (alias
      `correct_answer` / `kuncijawaban`), atau setidaknya nama header yang
      jelas menunjukkan itu.
  (b) Apakah skor TOTAL responden di file export = hitungan berbobot:
      bukan `benar / total_soal * 100` tapi `total_earned_points / total_max_points * 100`
      (proporsional dengan Points custom tiap soal).
- FR-D1-3: Tulis temuan JUJUR: LULUS / GAGAL / SEBAGIAN. Kalau GAGAL,
  dokumentasikan "BE export belum menambahkan kolom X / perhitungan Y" dan
  laporkan sebagai temuan terpisah — **JANGAN mengubah backend.**

## Non-Functional Requirements
- **NFR-1 (Zero Backend Change)**: Tidak ada file apapun di folder `/api`
  yang diubah, ditambah, atau dihapus. Commit hasil batch ini hanya
  menyentuh file di bawah `web/form-fe/src/**`.
- **NFR-2 (Zero Mobile Change)**: Tidak ada file di folder `/mobile/**`
  yang diubah.
- **NFR-3 (Zero Impact to Existing Working Features)**: Fitur yang sudah
  terintegrasi baik (Exam Monitoring live dashboard, OTP 2-step register,
  attempts history responden, force-submit/reset session, AI generator
  soal via Gemini modal) TIDAK BOLEH berubah behavior dan TIDAK BOLEH
  error. Diuji smoke test setiap fitur.
- **NFR-4 (Race Condition Safe)**: A-1 interceptor refresh token harus
  memakai mutex pattern, sehingga 5 request paralel 401 bersamaan HANYA
  memicu 1 kali refresh (bukan 5).
- **NFR-5 (Idempotent UI Import)**: Klik "Import Sekarang" dua kali cepat
  tidak mengakibatkan 2x import double. Tombol auto-disabled selama
  loading commit.
- **NFR-6 (Performance Form Builder)**: Dengan pagination C-2 aktif,
  waktu initial render Form Builder untuk form 150 soal tidak boleh lebih
  dari 2 detik di dev environment (karena cuma load 25 soal halaman 1,
  bukan 150).
- **NFR-7 (Accessibility Dasar)**: Semua tombol/input baru minimal punya
  aria-label yang masuk akal, modal punya close button, dan tidak ada
  trap focus yang fatal.

## Constraints
- **Technical**:
  - Stack FE yang dipakai: React 18 (Vite) + TailwindCSS. Ikuti pola
    komponen & apiService.js yang sudah ada, TIDAK boleh menambah dependensi
    baru tanpa persetujuan user (kecuali dependensi seperti `@dnd-kit`
    tidak dipakai di batch ini). Semua implementasikan dengan vanilla React
    state + hooks + Tailwind + komponen UI yang sudah ada.
  - Fetch client: project memakai fetch vanilla, BUKAN axios. Interceptor
    diimplementasikan dengan wrapper function di `apiService.js`, bukan
    switch ke axios.
  - Token storage: `localStorage` via `getToken()/setToken()` di
    `apiService.js` (JANGAN ganti mekanisme storage).
  - Form state existing: pakai `useState`/`useReducer` yang sedang
    digunakan di `FormBuilder.jsx` (tidak refactor ke Zustand/Redux).
- **Business**:
  - Tidak menambah charge / API cost baru untuk user — semua parsing import
    (PDF/DOCX) dijalankan SERVER-SIDE (backend), FE hanya upload file.
- **Dependencies**:
  - Hanya bergantung pada endpoint BE yang tercantum; tidak ada third-party
    API key lain.
  - `/api/templates/import-questions` di `apiService.js:533` diandalkan
    untuk link download template. Jika endpoint belum ada, fallback:
    hilangkan linknya saja (catat sebagai temuan non-blocking) — JANGAN
    menambah endpoint BE.

## Assumptions
- AS-1: Endpoint `POST /api/auth/refresh` di `AuthController.cs:146`
  mengembalikan struktur `ApiResponse<object>` yang BERISI field `token`
  dan `expiresAt` dalam `data`, sama seperti `Login`/`VerifyRegistration`
  (karena function `refreshToken()` di FE `apiService.js:98` menyimpan
  token seperti response login). Kalau format beda = gap kontrak dan
  dilaporkan.
- AS-2: Endpoint `/questions/import/preview` response JSON key
  (`canImport`, `blocked`, `totalRows`, `totalQuestions`, `errors[]`,
  `questions[].image`, `questions[].hasCorrectAnswer`, ...) sesuai yang
  saya catat di `QuestionsController.cs:577-606`. Kalau ada field yang
  berbeda nama (snake_case vs camelCase) FE menyesuaikan di parser
  function — tetap tanpa ubah BE.
- AS-3: Halaman "Detail Responden" yang memuat jawaban 1 responden lengkap
  sudah ada (referensi `getResponseDetail` / `FormResponsesPage.jsx` expand
  detail). Saya akan temukan file path nya saat implement phase; jika
  struktur file berubah, saya menyesuaikan saja.
- AS-4: `apiService.js` function `getAllQuestions()` SUDAH SUPPORT parameter
  `{ page, pageSize, search }` dalam bentuk destructuring atau query
  string. Kalau belum, saya wrap / modifikasi function `getAllQuestions()`
  SECARA BACKWARD COMPATIBLE — call tanpa parameter = behavior lama load
  semua soal (TANPA pagination).

## Acceptance Criteria

### AC-A1.1: Auto Refresh Token Transparan (Rule)
- **Type**: `rule`
- **Given**: User sedang login, token JWT sudah `expired` (disimulasikan
  dengan mengganti isi `localStorage.formup_token` dengan token dummy
  expired / atau server balik `Token-Expired: true` di header 401).
- **When**: User melakukan 1 aksi API yang butuh auth (contoh: klik
  `Simpan` di Form Builder yang call `PUT /questions`).
- **Then**: (1) FE otomatis panggil `POST /api/auth/refresh` 1x, (2)
  token baru tersimpan di localStorage, (3) request `PUT /questions`
  di-RETRY dengan token baru, (4) save BERHASIL, user HANYA melihat
  toast "Simpan berhasil" — tidak di-redirect ke login, tidak ada pesan
  error. Data edit form tidak hilang.
- **Pass Condition**: 100% percobaan di atas berhasil, tanpa perlu user
  klik F5 atau login ulang.
- **Evidence**: Screenshot Network tab DevTools (urutan request:
  `/questions → 401 Token-Expired → /auth/refresh → 200 → /questions retry → 200`),
  + toast sukses tampil.

### AC-A1.2: Refresh Token Gagal → Pesan Jelas (Rule)
- **Type**: `rule`
- **Given**: Endpoint `/api/auth/refresh` juga return 401 (karena refresh
  token juga expire / user invalid).
- **When**: Skenario AC-A1.1 dijalankan.
- **Then**: (1) Token di localStorage DIBERSIHKAN, (2) User di-redirect ke
  `/login`, (3) Toast atau banner merah muncul: "Sesi Anda telah berakhir.
  Silakan login kembali." — TIDAK silent redirect tanpa pesan.
- **Pass Condition**: 100% percobaan: redirect + clear storage + pesan jelas.
- **Evidence**: Screenshot halaman login setelah redirect dengan pesan.

### AC-A1.3: Refresh Tidak Terganda Pararel (Rule)
- **Type**: `rule`
- **Given**: 5 request API ke endpoint berbeda dipanggil BERSAMAAN (paralel)
  saat token expired.
- **When**: Semua 5 return 401 Token-Expired.
- **Then**: Hanya ada 1 panggilan ke `/api/auth/refresh` (bukan 5x), dan
  KELIMA request asli berhasil di-retry dengan token yang sama.
- **Pass Condition**: Network tab menunjukkan tepat 1 baris `/auth/refresh`.
- **Evidence**: Screenshot Network tab jumlah request `/auth/refresh`.

### AC-A2.1: Alur Import Excel Sukses (Rule)
- **Type**: `rule`
- **Given**: Form BARU (tidak punya responden) dibuka di Form Builder.
  File Excel `.xlsx` dengan 10 soal (8 valid, 2 baris error sengaja)
  siap upload sesuai format template.
- **When**: Klik "Import Soal dari File" → pilih file Excel → proses
  preview → review baris error → klik "Import Sekarang".
- **Then**: (1) Modal PREVIEW menampilkan baris merah untuk 2 error
  (sesuai `rowNumber` dan pesan BE); (2) Setelah commit, 8 soal BARU
  muncul di daftar soal Form Builder TANPA reload halaman; (3) Toast
  sukses tampil dengan jumlah benar: "8 soal berhasil diimpor, 2 dilewati".
- **Pass Condition**: Seluruh alur selesai tanpa error UI, soal count di
  Form Builder bertambah 8, dan data tiap soal sesuai file.
- **Evidence**: Screenshot preview modal (ada baris merah error) +
  screenshot Form Builder sesudah import (soal-soal tampil).

### AC-A2.2: Alur Import PDF/DOCX Sukses (Rule)
- **Type**: `rule`
- **Given**: File `.pdf` atau `.docx` berisi daftar soal PG sederhana (2-5 soal)
  yang BE parser bisa mengenali (`ParseStructuredEntries`).
- **When**: Jalankan alur import A2, ganti file pick ke PDF/DOCX.
- **Then**: Preview terisi, commit bisa berjalan, soal muncul di builder.
- **Pass Condition**: Minimal 1 format selain Excel (PDF / DOCX) berhasil
  import penuh (preview + commit).
- **Evidence**: Screenshot file PDF di picker + preview + soal hasil di builder.

### AC-A2.3: Form Sudah Ada Responden = Import Diblokir (Rule)
- **Type**: `rule`
- **Given**: Form yang SUDAH punya minimal 1 responden (bukan form baru).
- **When**: Klik Import → pilih file valid → preview return `blocked: true`.
- **Then**: Tombol "Import Sekarang" dalam keadaan DISABLED (abu abu tidak
  bisa diklik). Di atas tombol muncul teks peringatan MERAH: "Form sudah
  memiliki responden; soal tidak bisa ditambahkan via impor. Buat salinan
  form untuk menambah soal."
- **Pass Condition**: Tombol disabled + pesan muncul; user tidak bisa
  memaksa commit import.
- **Evidence**: Screenshot modal import dengan tombol disabled + pesan.

### AC-B1.1: Simpan Bobot Poin Konsisten di Backend (Rule)
- **Type**: `rule`
- **Given**: Form di builder dengan 3 soal: Soal 1 → Points = 2, Soal 2 →
  Points = 3, Soal 3 (essay) → Points = 5.
- **When**: Klik Simpan Form (PUT /questions bulk save), lalu buka reload
  halaman Form Builder F5.
- **Then**: Nilai Points tiap soal TETAP = 2, 3, 5 (tidak kembali ke 1 /
  hilang). Info header "Total Maksimal Skor" = 2+3+5 = 10 poin.
- **Pass Condition**: Nilai persisted di DB setelah reload.
- **Evidence**: Screenshot input Points di 3 card + total 10 di header,
  lalu same screenshot setelah F5 reload (nilai tetap).

### AC-B1.2: Perhitungan Skor Berbobot Proporsional (Rule)
- **Type**: `rule`
- **Given**: Form 3 soal @2, 3, 5 poin (total 10) seperti B1.1. Soal 1 PG
  jawaban benar, Soal 2 PG salah, Soal 3 essay kosong (tidak dikoreksi).
- **When**: Submit 1 responden dengan scenario di atas, buka halaman Hasil
  skor responden.
- **Then**: Skor TOTAL responden = (2/10) * 100 = **20** (BUKAN 33.33 dari
  asumsi default 1 poin per soal). Skor di halaman hasil, analytics, dan
  export = ANGKA YANG SAMA 20.
- **Pass Condition**: Skor = 20 bukan 33.33.
- **Evidence**: Screenshot halaman skor responden angka "20".

### AC-B2.1: Override Skor Essay Tersimpan & Skor Total Berubah (Rule)
- **Type**: `rule`
- **Given**: 1 responden submit soal essay di atas (B1.1 Soal 3, bobot 5
  poin), nilai skor otomatis = 0 / 5 karena jawaban kosong.
- **When**: Buka halaman Detail Responden → scroll ke soal essay → isi:
  `Skor Manual = 4`, centang `Override: Jawaban ini benar`, isi Catatan:
  "Bagus, hampir sempurna" → klik Simpan Koreksi → reload halaman.
- **Then**: (1) Setelah reload, input skor manual tetap = 4, checkbox
  override tetap check, catatan tetap ada (persisted); (2) Skor TOTAL
  responden SEKARANG = soal1 benar (2) + soal3 override benar (scored
  manual 4 dari bobot 5) → pro-rata: (2+4)/10*100 = 60 (BUKAN 20 lagi).
- **Pass Condition**: Semua value persisted + skor total = 60.
- **Evidence**: Screenshot panel koreksi essay + skor total responden
  "60" di header detail.

### AC-C1.1: Delete All Soal Berhasil dengan Konfirmasi (Rule)
- **Type**: `rule`
- **Given**: Form Builder punya 5 soal aktif.
- **When**: Klik "Kosongkan Semua Soal" → konfirmasi dialog → Ya, Hapus.
- **Then**: (1) Count soal di state = 0, (2) Reload halaman F5 → soal
  BENAR-BENAR 0 (terkonfirmasi BE DELETE ter-persist), (3) Total
  Maksimal Skor di header = 0 poin.
- **Pass Condition**: 0 soal setelah reload.
- **Evidence**: Screenshot list kosong builder + reload list masih kosong.

### AC-C2.1: Search & Pagination Soal Fungsi Normal (Rule)
- **Type**: `rule`
- **Given**: Form Builder dengan 45 soal, soal nomor 11-15 mengandung kata
  unik "Termodinamika". pageSize default = 20.
- **When**: (a) Pertama buka form → halaman 1 load 20 soal, pagination UI
  MUNCUL (halaman 1/X dengan X=3). (b) Klik halaman 3 → 5 soal terakhir
  muncul. (c) Isi search: "Termodinamika" → debounce 250ms → hanya 5
  soal nomor 11-15 muncul (hanya 1 halaman, pagination UI HILANG karena
  ≤ pageSize).
- **Then**: Semua aksi (a)(b)(c) berjalan sesuai harapan tanpa error.
- **Pass Condition**: tiap langkah sesuai deskripsi.
- **Evidence**: Screenshot (a) halaman 1 20 soal + pagination; (b) halaman 3 5 soal; (c) search Termodinamika hasil 5 soal.

### AC-D1.1: Verifikasi Export Kunci Jawaban & Bobot (Rubric)
- **Type**: `rubric`
- **Dimension**: Kelengkapan kolom & ketepatan perhitungan pada file
  export CSV/XLSX setelah B-1 berjalan.
- **Scale**: 0-5
- **Anchors**: 0 = kolom kunci jawaban TIDAK ADA & skor salah total; 2 =
  kolom kunci ada tapi skor TIDAK proporsional dengan Points; 3 = minimal
  salah SATU format (CSV ATAU XLSX) lengkap kunci + skor berbobot; 5 =
  KEDUA format (CSV DAN XLSX) keduanya: kolom kunci jelas, skor sesuai
  rumus Points berbobot, tidak ada kolom yang salah label.
- **Pass Threshold**: >= 3. Minimum 1 dari 2 format export LOLOS.
- **Evidence**: Screenshot 2 file spreadsheet (CSV & XLSX) dibuka di
  editor; catatan tertulis JUJUR hasil cek manual.

### AC-GLOBAL.1: Zero Backend & Zero Mobile Change (Rule)
- **Type**: `rule`
- **Given**: Seluruh batch 11 selesai implement.
- **When**: Jalankan perintah `git status --porcelain` / `git diff --name-only`
  untuk lihat daftar file berubah.
- **Then**: (1) TIDAK ADA 1 file pun di path `api/**` yang muncul di list
  file modified. (2) TIDAK ADA 1 file pun di path `mobile/**` yang muncul.
  Semua perubahan file HANYA di `web/form-fe/src/**`.
- **Pass Condition**: git diff name-only hanya file web/form-fe/src/.
- **Evidence**: Output command git diff / screenshot VS Code source control
  panel list perubahan.

### AC-GLOBAL.2: Fitur Existing Tidak Regresi (Rule)
- **Type**: `rule`
- **Given**: Batch 11 selesai.
- **When**: Smoke test 5 fitur existing berikut secara manual di web app:
  (1) Login via email & password (bukan OTP) berhasil; (2) Buka form ujian
  Exam Monitoring dengan 1 sesi ujian aktif → force-submit tombol berjalan
  (status response berubah); (3) AI Generator Modal call
  `streamGenerateQuestionsWithAI()` pakai key user → berhasil generate 5
  soal PG; (4) Tombol Export CSV di Analytics → file bisa di-download;
  (5) User buka link form public tanpa login → bisa isi soal + submit.
- **Then**: 5 smoke test LULUS SEMUA. Tidak ada error console yang fatal.
- **Pass Condition**: 5/5 = 100% smoke test.
- **Evidence**: Catatan checklist per test di tasks.md completion evidence.

## Open Questions
- [ ] **OQ-1**: Path HALAMAN DETAIL RESPONDEN yang menampilkan jawaban per
  siswa lengkap (untuk B-2 UI scoring): apakah komponennya ada di
  `FormResponsesPage.jsx` sebagai expandable row, atau sebagai page
  terpisah? (Saya akan cari sendiri saat implement phase dengan grep
  `getResponseDetail`, kalau struktur tidak sesuai saya catat di task,
  tidak block.)
- [ ] **OQ-2**: Apakah download template di `/api/templates/import-questions`
  benar-benar mengembalikan blob/xlsx? Kalau return 404, saya akan hapus
  link download template dan catat sebagai temuan (tidak block).
- [ ] **OQ-3**: Apakah `saveQuestions` bulk PUT endpoint menerima camelCase
  field `points` di body JSON? Atau harus PascalCase `Points`? (Saya akan
  coba dulu camelCase sesuai pola FE lain di `apiService.js`; kalau BE
  tidak tangkap, saya cek dengan request devtools dan catat — asumsi:
  karena JsonOptions di `Program.cs:44-49` set
  `PropertyNamingPolicy = CamelCase`, maka FE kirim `points` sudah benar.)
