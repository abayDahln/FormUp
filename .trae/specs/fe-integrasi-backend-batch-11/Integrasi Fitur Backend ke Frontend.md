# Integrasi Fitur Backend ke Frontend

> **Workspace:** /home/karllo/Projects/FormUp

---

**User**

baca specs terlebih dahulu,kamu ga perlu buat spec lagi,nant isaya kirim prompt itu hanya sebgaai reminder aja harus ngapain,kamu lanjutin sisa sisanya,baja speec,tasks.md,dan fitur otomatisasi.md disini itu progress sebelumnnya yang kepotong

```
# TASK: Integrasi Fitur Backend yang Belum Terpakai di FE — Form/Quiz Builder App (Batch 11)

## 📋 KONTEKS
Hasil audit menyeluruh terhadap 18 file backend yang berubah menemukan
**6 kelompok fitur backend sudah selesai & siap pakai**, tapi sebagian besar
**belum punya UI di frontend web** — beberapa bahkan sudah ada function
`apiService.js`-nya, tinggal dipasangkan ke komponen. Batch ini fokus
memasangkan UI untuk fitur-fitur yang "terkubur" tersebut, sesuai urutan
prioritas dampak ke user.

**Fitur yang SUDAH terintegrasi dengan baik (JANGAN disentuh/refactor,
hanya untuk konteks):** OTP Register (2-step), riwayat attempt responden,
Exam Monitoring & heartbeat/force-submit/reset (dashboard proctoring sudah
sinkron FE-BE), update status response, `ReferenceCache` (transparan, tidak
butuh perubahan FE), rate limiting policies.

## ⚠️ ATURAN WAJIB
1. **FRONTEND ONLY.** Semua field/endpoint di bawah **sudah tersedia di
   backend** — tugas kita murni membuat UI dan memanggilnya. **Jangan ubah
   backend sama sekali.** Kalau ternyata ditemukan gap kontrak (field yang
   didokumentasikan ternyata tidak ada di response asli), laporkan sebagai
   temuan terpisah, jangan tambal di backend.
2. **HANYA WEB APP** — jangan sentuh kode mobile app.
3. **JANGAN sentuh/rusak kode yang sudah berjalan baik** di luar scope item
   di bawah — khususnya fitur yang sudah terintegrasi baik (lihat daftar di
   atas), jangan direfactor "sambil lewat".
4. Kerjakan sesuai urutan **BAGIAN A → B → C → D** (prioritas dari dampak
   tertinggi ke terendah). Kalau waktu terbatas, BAGIAN A wajib selesai dulu.

---

## BAGIAN A — PRIORITAS TERTINGGI (Risiko Kehilangan Data / Fitur Besar Belum Bisa Dipakai)

### A-1: Auto Refresh Token Interceptor — mencegah kehilangan data akibat token expired

**Masalah saat ini:**
- Backend sudah mengirim header **`Token-Expired: true`** saat JWT expire,
  dan endpoint `POST /api/auth/refresh` sudah tersedia untuk tukar token baru
  tanpa perlu login ulang.
- `apiService.js` **sudah punya** function `refreshToken()`, TAPI **tidak
  pernah dipanggil otomatis** — tidak ada interceptor yang mendeteksi respons
  gagal karena token expired, lalu otomatis refresh dan mengulang request asli.
- **Dampak nyata:** kalau user sedang mengedit form lama (misal 1-2 jam
  tanpa logout), lalu token expire di tengah jalan, request **save akan
  gagal secara SILENT** (kemungkinan cuma tercatat di `console.log`, tidak
  ada notifikasi ke user) — **perubahan yang sudah dikerjakan bisa hilang**
  tanpa user sadar.

**Yang harus dikerjakan:**
1. Buat **wrapper/interceptor terpusat** di layer HTTP client (`apiService.js`
   atau layer fetch/axios yang dipakai project) yang:
   - Mendeteksi response dengan header `Token-Expired: true` (atau status
     401 sesuai kontrak yang berlaku — cek dokumentasi/behavior asli backend).
   - Otomatis memanggil `refreshToken()` yang sudah ada.
   - Kalau refresh berhasil: simpan token baru, **ulangi request original**
     yang gagal tadi secara otomatis (transparan ke pemanggil, tidak perlu
     user klik ulang).
   - Kalau refresh GAGAL (refresh token juga sudah expired/invalid): baru
     redirect ke halaman login, dengan pesan yang jelas ("Sesi berakhir,
     silakan login kembali") — JANGAN silent redirect tanpa penjelasan.
2. Pastikan interceptor ini berlaku untuk **SEMUA request API** yang butuh
   auth (bukan cuma sebagian endpoint tertentu) — pasang di level paling
   sentral, bukan ditempel di tiap pemanggilan API satu-satu.
3. Tangani **race condition**: kalau ada beberapa request paralel gagal
   bersamaan karena token expired (misal user save form yang trigger 3
   request sekaligus), pastikan **hanya 1 kali proses refresh** yang berjalan
   (bukan 3x refresh bersamaan), lalu semua request yang tertunda memakai
   token baru yang sama setelah refresh selesai.
4. **Test wajib:** simulasikan token expired di tengah proses edit (bisa
   pakai token dummy yang sengaja di-expire manual di dev tools/local storage,
   atau ubah durasi expiry sementara di environment testing), lalu coba
   save — pastikan save tetap berhasil tanpa user perlu login ulang manual,
   dan tidak ada data yang hilang.

### A-2: UI untuk Import Soal dari File (Excel/CSV/PDF/Word) — fitur terbesar yang belum punya tampilan

**Fitur backend yang sudah siap (belum ada UI-nya sama sekali):**
- `POST /api/forms/{id}/questions/import/preview` — upload file, dapat
  preview hasil parsing (misal 100 soal pertama) + daftar error per baris
  (`rowNumber`, `field` yang salah), **belum masuk database** (murni preview).
- `POST /api/forms/{id}/questions/import` — commit hasil import ke database
  (dipanggil setelah user review preview & yakin).
- Mendukung 5 format file: `.xlsx`, `.xls`, `.csv`, `.pdf`, `.docx`.
- Backend mendeteksi tipe file dari **isi file asli** (bukan cuma ekstensi
  nama file), dan auto-detect kolom kunci jawaban dari beberapa nama alias
  (`correct_answer`, `jawabanbenar`, `kuncijawaban`, `kunci`, `answer`).
- `apiService.js` **sudah punya** function `importQuestions()` — tapi belum
  pernah dipanggil dari komponen manapun karena tidak ada UI trigger.

**Yang harus dikerjakan:**
1. Tambahkan tombol **"Import Soal dari File"** di halaman Form Builder
   (dekat tombol tambah soal manual / tombol aksi lain yang relevan).
2. Buat **dialog/modal upload file**: file picker yang membatasi tipe file
   ke 5 format yang didukung (`.xlsx`, `.xls`, `.csv`, `.pdf`, `.docx`).
3. Setelah file dipilih, panggil endpoint **`.../import/preview`** dulu
   (BUKAN langsung commit), lalu tampilkan hasilnya dalam **tabel preview**:
   - List soal yang berhasil terbaca (nomor, teks soal, tipe, opsi jawaban,
     kunci jawaban yang terdeteksi).
   - **Highlight/tandai baris yang error** dengan jelas (warna merah/badge),
     tampilkan pesan error spesifik per baris (dari `rowNumber` & `field`
     yang dikirim backend) supaya user tahu persis baris & kolom mana yang
     harus diperbaiki di file aslinya.
   - Tampilkan ringkasan jumlah: total baris, berhasil, error.
4. Tambahkan tombol **"Import Sekarang"** di preview (aktif kalau minimal
   ada 1 soal valid), yang baru memanggil endpoint commit **`.../import`**
   untuk benar-benar menyimpan ke database.
5. Tampilkan **progress indicator** selama upload & proses (terutama untuk
   file besar/PDF yang butuh parsing lebih lama).
6. Setelah import berhasil, refresh daftar soal di Form Builder supaya
   soal yang baru diimport langsung terlihat tanpa perlu reload manual.
7. Sertakan link/tombol **"Download Template"** (kalau ada endpoint template
   yang sudah dirujuk `apiService.js` di `/api/templates/import-questions`)
   supaya user tahu format kolom yang benar sebelum upload.

---

## BAGIAN B — PRIORITAS TINGGI

### B-1: Input Bobot Poin (`Points`) per Soal di Form Builder

**Fitur backend yang sudah siap:**
- Field `Points` di tiap soal sudah didukung penuh di backend — tersimpan
  saat save, di-expose ke Form Runner, dan **sudah dipakai dengan benar**
  dalam perhitungan skor rata-rata & export di `AnalyticsController`.
- **Satu-satunya yang kurang: tidak ada input field di UI Form Builder**,
  sehingga fitur bobot custom per soal ini sama sekali tidak bisa dipakai
  user (semua soal otomatis dianggap bobot default/1 poin).

**Yang harus dikerjakan:**
1. Tambahkan input angka **"Bobot Poin"** di form edit tiap soal (Form
   Builder), dengan nilai default masuk akal (misal 1 atau sesuai skema
   lama) supaya soal yang belum diisi manual tetap kompatibel dengan
   behavior lama.
2. Saat save soal (baik simpan 1 per 1 maupun bulk save), pastikan field
   `Points` ini ikut dikirim ke endpoint save yang sudah ada.
3. **Tampilkan total bobot form** di suatu tempat yang terlihat (misal di
   header Form Builder atau tab Publikasikan), supaya guru tahu total
   maksimal skor form-nya (relevan dengan fitur bobot custom dari batch
   sebelumnya yang menyebutkan total skor tidak harus 100).
4. Test: buat form dengan beberapa soal berbobot beda-beda (misal 2 soal
   PG @2 poin, 1 soal essay @5 poin), submit sebagai responden, lalu cek
   di halaman hasil & analytics bahwa skor dihitung proporsional sesuai
   bobot yang diinput (bukan dianggap sama rata).

### B-2: UI Manual Scoring & Catatan untuk Soal Essay di Halaman Detail Responden

**Fitur backend yang sudah siap:**
- `PUT /api/responses/{id}/answers/{answerId}/score` — override skor manual
  per jawaban (field: `ManualScore` 0-1000, `IsCorrectOverride`, `OverrideNote`
  untuk catatan ke siswa).
- Endpoint bulk: `PUT /api/responses/{id}/scores` untuk update banyak
  jawaban sekaligus.
- `apiService.js` **sudah punya** function `updateAnswerScore()` — belum
  dipanggil dari UI manapun.

**Yang harus dikerjakan:**
1. Di halaman **Detail Responden** (tempat guru melihat jawaban 1 responden
   secara lengkap), untuk setiap soal tipe **Essay**, tambahkan:
   - Input angka untuk **skor manual** (`ManualScore`).
   - Toggle/checkbox untuk **override status benar/salah** (`IsCorrectOverride`)
     — untuk kasus di mana jawaban tidak exact match tapi guru menilai
     konsepnya benar.
   - Text area untuk **catatan ke siswa** (`OverrideNote`), misal "Bagus,
     tapi rumusnya kurang tepat."
   - Tombol **"Simpan Koreksi"** yang memanggil `updateAnswerScore()`.
2. Setelah simpan berhasil, pastikan **skor total responden ter-update** di
   UI (baik di halaman detail ini maupun daftar responden), mengikuti nilai
   manual yang baru diinput, bukan skor otomatis lama.
3. **Catatan integrasi dengan fitur AI Smart Scoring Essay** (dari batch
   sebelumnya, kalau sudah dikerjakan): pastikan tombol simpan skor manual
   ini dan alur "Terapkan Skor AI" memanggil endpoint yang SAMA/konsisten,
   supaya tidak ada 2 jalur kode berbeda yang saling menimpa.
4. Test: buka detail responden dengan soal essay, isi skor manual + centang
   override + tulis catatan, simpan, reload halaman, pastikan semua data
   tersimpan persis dan skor total ikut ter-update dengan benar.

---

## BAGIAN C — PRIORITAS SEDANG

### C-1: Tombol "Hapus Semua Soal" di Form Builder

**Fitur backend yang sudah siap:**
- `DELETE /api/forms/{id}/questions` — hapus SEMUA soal dalam form dengan
  1 request (tidak perlu loop delete satu-satu).

**Yang harus dikerjakan:**
1. Tambahkan tombol **"Kosongkan Semua Soal"** di Form Builder (kemungkinan
   di dalam menu aksi lainnya, sesuai reorganisasi tombol dari batch
   sebelumnya — cek dulu apakah sudah ada slot untuk ini).
2. **Wajib ada dialog konfirmasi** sebelum eksekusi (karena ini aksi
   destruktif & tidak bisa dibatalkan) — misal minta user mengetik ulang
   nama form atau klik konfirmasi dua langkah.
3. Setelah berhasil, refresh tampilan daftar soal jadi kosong tanpa reload
   manual.

### C-2: Pagination & Search di Daftar Soal (Form Builder)

**Fitur backend yang sudah siap:**
- `GET /api/forms/{id}/questions` sekarang mendukung query params
  `?page=&pageSize=&search=` untuk pagination dan pencarian teks soal.
- Saat ini Form Builder masih **load semua soal sekaligus** tanpa pagination,
  yang berpotensi lambat/lag untuk form dengan soal sangat banyak (100+).

**Yang harus dikerjakan:**
1. Tambahkan **search box** di atas daftar soal Form Builder, yang memfilter
   soal berdasarkan teks (memanggil ulang endpoint dengan parameter `search`).
2. Implementasikan **pagination** (baik infinite scroll atau nomor halaman,
   sesuaikan dengan pola UI yang sudah dipakai di halaman lain aplikasi ini)
   untuk form dengan jumlah soal besar, supaya tidak semua soal di-load
   sekaligus di awal.
3. Pastikan fitur **drag-and-drop reorder soal** (kalau ada) dan fitur lain
   yang bergantung pada urutan/daftar lengkap soal tetap berfungsi normal
   dengan adanya pagination ini — cek dan sesuaikan kalau ada konflik.
4. Untuk form dengan jumlah soal sedikit (misal di bawah `pageSize` default),
   pastikan behavior tetap sama seperti sebelumnya (tidak ada pagination UI
   yang muncul percuma kalau semua soal muat dalam 1 halaman).

---

## BAGIAN D — VERIFIKASI SAJA (Kemungkinan Sudah Otomatis Bekerja, Perlu Dicek Ulang)

### D-1: Export CSV/XLSX dengan Kunci Jawaban & Bobot Poin

Backend `AnalyticsController` kemungkinan besar **sudah** mengirim kolom
kunci jawaban dan memperhitungkan bobot `Points` di file export, dan karena
export biasanya berupa **direct download dari URL/endpoint**, perubahan ini
**seharusnya otomatis berlaku di FE tanpa perubahan kode**.
**Yang harus dilakukan:** BUKAN implementasi baru — cukup **verifikasi**:
1. Export CSV & XLSX dari halaman Analytics/Responses untuk form yang punya
   bobot custom (`Points` berbeda-beda per soal, setelah B-1 selesai).
2. Konfirmasi kolom kunci jawaban muncul dengan benar, dan angka/skor di
   file export sudah proporsional sesuai bobot.
3. Kalau ternyata ADA yang belum sesuai (misal kolom kunci tidak muncul,
   atau butuh toggle UI seperti yang sudah dibahas di batch sebelumnya),
   laporkan sebagai temuan — jangan buru-buru mengasumsikan "sudah otomatis
   fix" tanpa benar-benar mencoba export-nya.

---

## OUTPUT YANG DIHARAPKAN
1. **A-1:** demo/video simulasi token expired di tengah edit form, tunjukkan
   request tetap berhasil otomatis tanpa user re-login, dan tidak ada data
   yang hilang.
2. **A-2:** demo alur lengkap Import Soal — upload file → preview dengan
   error highlight → commit import → soal muncul di Form Builder. Sertakan
   test dengan minimal 2 format file berbeda (misal `.xlsx` dan `.docx`).
3. **B-1:** screenshot input bobot poin di Form Builder + bukti perhitungan
   skor proporsional di hasil pengerjaan & analytics.
4. **B-2:** screenshot UI manual scoring essay di Detail Responden + bukti
   skor total ter-update setelah override disimpan.
5. **C-1, C-2:** demo masing-masing fitur setelah selesai.
6. **D-1:** hasil verifikasi export (screenshot file CSV/XLSX), sertakan
   temuan apapun yang ternyata belum otomatis bekerja.
7. Konfirmasi eksplisit: **tidak ada file backend yang diubah**
8. Konfirmasi eksplisit: **tidak ada file mobile app yang disentuh**
9. Konfirmasi eksplisit: **fitur yang sudah terintegrasi baik (Exam
   Monitoring, OTP Register, attempts history, dll) tidak ikut berubah**
10. Daftar file yang diubah, dikelompokkan per item (A-1, A-2, B-1, B-2,
    C-1, C-2, D-1)
11. Bug/blocker/gap kontrak baru yang ditemukan selama implementasi
```

**Assistant**

Saya akan membaca file spec, tasks.md, dan Fitur Otomatisasi Aplikasi.md terlebih dahulu untuk memahami progress sebelumnya yang terputus, kemudian melanjutkan implementasi sisanya.

Saya lanjut membaca sisa file spec, tasks.md, dan bagian akhir dari Fitur Otomatisasi Aplikasi.md untuk memahami progress sebelumnya yang terputus.

Baik, saya sudah memahami semua spec dan rencana implementasi. Progress saat ini: **Semua 9 task masih `pending`, belum ada yang diimplementasikan.** Saya akan langsung lanjutkan implementasi dari Task 1 (A-1 Auto Refresh Token) sampai selesai, sesuai urutan prioritas yang sudah ditetapkan.

Pertama, mari saya eksplorasi struktur kode FE web dan baca file-file krusial yang akan diubah.

Menarik! Setelah membaca `apiService.js`, ternyata **Task 1 (A-1 Auto Refresh Token) SUDAH TERIMPELEMENTASI** (sudah ada `authFetch()` wrapper + `_performRefreshMutex()` mutex pattern). Mari saya lanjutkan membaca file-file lain untuk mengecek progress task yang lain.

Banyak fitur yang SUDAH TERIMPLIKASI! Task 1 (interceptor) dan Task 2 (ImportQuestionsModal) file-nya sudah ada. Mari saya lanjutkan membaca sisa FormBuilder.jsx untuk cek B-1, C-1, C-2, dan cek FormResponsesPage.jsx untuk B-2.

Hasil audit cepat: banyak fitur SEBAGIAN BESAR sudah terimplementasi! Saya daftarkan yang KURANG dan perlu diselesaikan:

**Kurang / Belum Sempurna:**
1. **Task 2 (A-2)**: Modal `ImportQuestionsModal.jsx` sudah ada, tapi **BELUM dipasang state trigger & tombol di UI FormBuilder**
2. **Task 3 (B-1)**: Input Points per soal ada, tapi **BELUM ADA "Total Maksimal Skor" live di header Form Builder**
3. **Task 4 (B-2)**: Koreksi parsial ada, tapi **BELUM ADA Textarea "Catatan ke Siswa (OverrideNote)"** sesuai spec FR-B2
4. **Task 5 (C-1)**: Clear questions hanya hapus state lokal, **BELUM call endpoint `deleteAllQuestions()` API**
5. **Task 6 (C-2)**: **BELUM ADA Search Box + Pagination** di Form Builder (load semua soal sekaligus)

Saya langsung perbaiki yang kurang. Update todo dan mulai implementasi.

Let's proceed with implementing the remaining gaps. First, let's work on T2FIX by editing FormBuilder.jsx to connect the ImportQuestionsModal.

---

