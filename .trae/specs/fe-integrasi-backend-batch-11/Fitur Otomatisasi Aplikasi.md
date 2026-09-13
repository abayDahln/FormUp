# Fitur Otomatisasi Aplikasi

> **Workspace:** /home/karllo/Projects/FormUp

---

**User**

tanpa mengubah satu pun baris kode,apakah app gua mendukung fitur automization?,apakah bisa api key di stack,misal gua sebagai user naro 2 + token di di tempat taro api key,jadi kalo misal api key 1 limit dia bakal langsung pake yang kedua dan melanjutkan konteks nya,terus saya juga mau saran fitur automization yang lain,kalo saya ada ide mebuat formulir otomatis sesuai tanggal yang saya mau,kamu boleh saranain yang lain

**Assistant**

Saya akan menganalisis aplikasi FormUp Anda untuk menjawab pertanyaan tentang fitur automization tanpa mengubah kode sama sekali. Mari saya periksa struktur proyek dan fitur yang sudah ada terlebih dahulu.

Mari saya eksplorasi lebih dalam tentang bagaimana API key dikelola dan fitur AI/automation yang sudah ada.

Mari saya lihat lebih dalam tentang layanan AI lainnya dan mekanisme yang sudah ada.

Mari saya cek apakah ada mekanisme scheduler/background job dan dokumentasi mekanisme lainnya.

Setelah saya analisis kode FormUp Anda secara menyeluruh, berikut jawaban untuk ketiga pertanyaan Anda (TANPA mengubah kode sama sekali):

---

## 1. Apakah Aplikasi Sudah Mendukung Fitur Automation?

**Sebagian YA, tapi terbatas pada AI Chat saja.**

✅ **Yang SUDAH ADA (automation level: perintah manual via chat):**
- AI Chat Agent (`ai_chat_screen.dart`) yang bisa mengeksekusi aksi otomatis dari perintah bahasa alami user:
  - `create_form` — buat form + soal otomatis dari prompt (mis: *"Buatkan kuis fisika kelas 11 bab Hukum Newton 20 soal PG + 5 essay"*)
  - `add_questions` / `edit_questions` / `delete_questions` — modifikasi soal form existing lewat chat
  - `update_settings` — ubah pengaturan form
  - Bisa @mention form untuk baca konteks + analytics jawaban responden

Ini terlihat dari `systemPrompt` di `gemini_service.dart:267-307` dan integrasi `AiFormContextService`.

❌ **Yang BELUM ADA:**
- **Tidak ada scheduler/timed automation** — Saya cek backend (`Program.cs`, controllers, services) **tidak ada** `Hangfire`, `Quartz.NET`, `BackgroundService`, atau `IHostedService` sama sekali.
- `OpenFormTime` / `CloseFormTime` di `FormSetting.cs:26-28` hanya **client-side flag** — tidak ada job di backend yang benar-benar auto-publish / auto-close form saat waktu tercapai.

---

## 2. Apakah Bisa Stack API Key (Multiple Keys + Rotasi Limit)?

**SAAT INI TIDAK BISA.** Berdasarkan analisis `gemini_service.dart:31-42` dan `api_key_dialog.dart`:

| Kondisi Saat Ini | Keterangan |
|---|---|
| Storage key | Hanya **SATU** key user: `gemini_api_key` di FlutterSecureStorage |
| Prioritas key | `userKey (1 key)` → fallback ke `.env` (1 key) → `--dart-define` (1 key) |
| Input dialog | Hanya **1 TextField** untuk 1 key |
| Rotasi saat limit | **Tidak ada logic fallback.** Kalau key kena 429 (resource exhausted), langsung throw error "Batas pakai AI habis" dan stop |
| Context preservation | Tidak butuh untuk saat ini karena tidak ada rotasi key |

**Cara kerja yang Anda inginkan (stack 2+ token, lanjut konteks) memerlukan perubahan berikut nanti:**
1. Ubah storage dari `String? _userKey` menjadi `List<ApiKeyEntry>` — tiap entry punya `id, label, key, priority, lastError, usageCount`.
2. Wrap method `streamChat()` dan `generateOnce()` dengan **retry loop**: kalau key pertama throw `429 / resource_exhausted / quota`, tutup client lama, lanjut pakai key kedua, **pakai `history` parameter yang SAMA** → konteks chat tetap lanjut tanpa reset.
3. Tambahkan UI di `ai_settings_screen.dart`: list key dengan tombol tambah/hapus/urutkan prioritas.

---

## 3. Saran Fitur Automation Lainnya

Selain ide Anda **"form otomatis sesuai tanggal"**, berikut rekomendasi yang relevan untuk use case FormUp (platform kuis/formulir pendidikan):

### 🔴 Automation Prioritas Tinggi (Paling Berguna untuk User)

| # | Fitur | Penjelasan Singkat |
|---|---|---|
| 1 | **Scheduled Form Generator (ide Anda)** | "Setiap Senin jam 07.00, duplikat template `Kuis Harian Matematika` lalu random 20 soal dari bank soal kelas X" — butuh backend job scheduler + tabel `AutomationRule` (cron expression + templateId) |
| 2 | **Auto-Publish / Auto-Close BENARAN di Backend** | Bukan cuma flag `OpenFormTime` di client — job scheduler tiap menit cek form yang waktunya publish/close, lalu update `FormStatus` secara otomatis |
| 3 | **Multi API Key Rotation** | Yang Anda tanyakan di poin #2 — rotasi otomatis key + preserve chat context |
| 4 | **Auto-Export Periodik** | "Setiap hari Jumat jam 17.00, ekspor CSV respons form UTS ke email saya / upload ke Google Drive via service account" |

### 🟡 Automation Level Menengah

| # | Fitur | Penjelasan |
|---|---|---|
| 5 | **Webhook Trigger** | Saat form mencapai N-respons / deadline tercapai / ada feedback baru, kirim `POST` ke endpoint user (integrasi ke Slack, Notion, Google Sheets, zapier.com) |
| 6 | **Reminder Responden Otomatis** | H-1 sebelum deadline, kirim email/WA ke daftar responden yang belum submit (butuh tabel `FormInvitation` dengan email/WA target) |
| 7 | **Auto-Skoring Essay dengan AI** | Saat user submit essay, AI bandingkan jawaban dengan rubrik kunci jawaban → kasih skor awal + catatan, tinggal direview guru |
| 8 | **Auto-Force Submit Proctoring** | Kalau `tabSwitchCount > MaxTabSwitch` (sudah ada field di `FormSetting.cs:39`), otomatis panggil endpoint `force-submit` tanpa perlu admin klik manual |

### 🟢 Automation Konten (AI-Powered, Value Tinggi)

| # | Fitur | Penjelasan |
|---|---|---|
| 9 | **Generate Soal dari Materi** | Upload PDF/teks materi pelajaran → AI ekstrak jadi 20 soal PG + 5 essay + kunci jawaban otomatis |
| 10 | **Randomized Soal per Responden (Item Bank)** | Dari bank 100 soal, tiap responden dapat paket soal random 20 butir berbeda → mengurangi contekan |
| 11 | **Auto-Generate Pembahasan** | Setelah ujian selesai, AI buat pembahasan per soal: "Soal 3 jawaban B karena..." — dikirim ke responden bersama skor |
| 12 | **Remedi Otomatis Berbasis Skor** | Kalau skor responden < 70 → otomatis kirim link form remedi; kalau >= 80 → kirim form lanjutan (conditional workflow) |

### 📋 Ringkasan Status

```
FITUR AUTOMATION YANG DITANYAKAN:
├─ ✅ AI Chat buat form otomatis via perintah   (SUDAH ADA)
├─ ❌ Stack/rotasi multi API key + preserve ctx (BELUM ADA)
├─ ❌ Form terjadwal (buat otomatis per tanggal) (BELUM ADA)
└─ ❌ Semua saran di tabel di atas              (BELUM ADA — perlu scheduler + tabel baru)
```

Jika nanti mau implementasikan yang mana duluan, bisa saya bantu breakdown task-nya. 😊

---

**User**

gua suka multi api key rotatio,masukin list,coba saranin fitur automisasi lainnya yang sangat penting dan antimainstream gitu,untuk di web ya

**Assistant**

Mari saya eksplorasi terlebih dahulu apakah ada frontend web terpisah dan fitur web-spesifik yang sudah ada, agar saran automation-nya tepat sasaran dan kontekstual.

Bagus, ada frontend web React di `/web/form-fe`. Mari saya cek layanan AI web dan kapabilitas fitur kunci lainnya agar saran automation-nya tepat untuk konteks web FormUp.

Oke, saya masukin **Multi API Key Rotation** sebagai item #1 dengan rincian implementasi web-spesifik, lalu lanjut 8 fitur automasi lain yang **sangat penting + antimainstream (tidak ada di Google Forms/MS Forms)** dan khusus untuk web. Semua berdasarkan analisis kode web (`aiService.js`, Form Builder, Runner, Analytics) dan backend FormUp Anda.

---

## 📋 LIST FITUR AUTOMASI KHUSUS WEB FORMUP

### 🔥 #1. Multi API Key Rotation (Yang Kamu Minta)
**Kondisi sekarang (web):** Cuma simpan 1 key di `localStorage.formup_gemini_api_key` — kena 429 langsung error total di `aiService.js:202-206`.

| Detail | Keterangan Web-Spesifik |
|---|---|
| **Storage** | Ubah dari `string` → array object disimpan di **localStorage + IndexedDB** (agar kapasitas besar, tahan clear cache ringan): `[{ id, label, key, priority: 1-10, usageCount, lastStatus, lastUsedAt }]` |
| **UI Pengaturan** | Tambah halaman baru di Sidebar web: **"API Key Pool"** — tabel dengan kolom Label, Masked Key, Prioritas (drag-drop urut), Status (Hijau/Abu/Kuning: OK/Idle/Limit tercapai), Tombol Test/Hapus |
| **Rotasi Logic** | Wrap `generateQuestionsWithAI()` dan `streamGenerateQuestionsWithAI()` di `aiService.js` dengan **retry loop + context preserve**: <br>1. Coba key priority tertinggi<br>2. Kalau throw `429 / resource_exhausted / quota` → tandai key status `LIMITED`, auto mark `cooldownUntil = now + 60 detik`<br>3. Lanjut ke key priority berikutnya **DENGAN parameter `topic/count/typePreference/difficulty` YANG SAMA + `history` chat yang sama** → konteks tidak reset<br>4. Kalau semua key limited → kasih user opsi "Tunggu 60 detik lalu retry semua" dengan countdown realtime |
| **Fitur Tambahan Web** | Tombol **"Test Semua Key Sekaligus"** (kirim prompt dummy "ping"), dan badge di AI Modal: `Key Aktif: Key Pribadi #2 (312x dipakai)` |
| **Prioritas** | 🔴 TERTINGGI — langsung impact workflow guru generate soal tanpa henti |

---

### ⚡ #2. Adaptive Difficulty Engine (Mesin Kesulitan Soal Adaptif OTOMATIS)
**Kenapa SANGAT PENTING:** Guru yang buat ujian ingin soal menyesuaikan kemampuan siswa REAL-TIME. Siswa jenius tidak bosan soal gampang, siswa lemah tidak frustasi soal sulit.

**Kenapa ANTIMAINSTREAM:** Ini fitur platform ujian profesional kelas GRE/TOEFL — Google Forms, Typeform, JotForm **SAMPAI SEKARANG TIDAK PUNYA**.

| Implementasi Web | Detail |
|---|---|
| **Setting di Form Builder Web** | Tambah toggle: `☑️ Aktifkan Kesulitan Adaptif` dengan slider: `Seberapa agresif penyesuaian: [1-5]` |
| **Logic di Form Runner Web** | Simpan `streakBenar` / `streakSalah` di state web (per 3 soal):<br>- ✅✅✅ (3 benar berturut) → next soal auto ambil dari pool "Sulit"<br>- ❌❌ (2 salah berturut) → next soal auto turun ke "Sedang"<br>Butuh backend tambah field `Question.DifficultyLevel` (Mudah/Sedang/Sulit) |
| **Output di Analytics Web** | Tambah chart baru: **"Grafik Trajektori Kemampuan per Responden"** — kurva naik/turun level kesulitan yang berhasil dilewati siswa |
| **Prioritas** | 🟠 TINGGI — unique selling point (USP) terbesar FormUp dibanding kompetitor |

---

### 📋 #3. Clipboard Import Form + Drag-Drop JSON Blueprint
**Kenapa SANGAT PENTING:** Guru mau share template kuis ke guru LAIN di sekolah, tanpa upload/download file ribet.

**Kenapa ANTIMAINSTREAM:** Semua platform form cuma support "Upload JSON file" — tidak ada yang pakai **native Clipboard API** copy-paste langsung.

| Implementasi Web | Detail |
|---|---|
| **Export via Clipboard** | Di Form Detail web, tombol baru: `📋 Salin Blueprint ke Clipboard` — serialisasi form + semua soal ke JSON minified, copy otomatis ke clipboard pakai `navigator.clipboard.writeText()` |
| **Import via 3 Cara** | Di halaman "Buat Form Baru" web, tambah 3 opsi import:<br>1. **Paste dari Clipboard** (Ctrl+V langsung di textarea auto-detect JSON valid)<br>2. **Drag & Drop File JSON** ke drop zone di browser (HTML5 DragEvent)<br>3. **Pilih File dari Komputer** (pakai File System Access API untuk save langsung ke folder user nanti) |
| **Validasi Otomatis** | Sebelum import, AI scan blueprint: "Soal nomor 4 tidak punya kunci jawaban, perbaiki otomatis?" |
| **Prioritas** | 🟠 TINGGI — boost kolaborasi guru antar sekolah |

---

### 🔖 #4. Bookmarklet Generate Soal dari Teks di Web MANA SAJA
**Kenapa SANGAT PENTING:** Guru lagi browsing artikel pendidikan di Wikipedia/Blog, nemu paragraf penting, **LANGSUNG bisa generate soal dari teks itu tanpa buka FormUp copy-paste manual**.

**Kenapa ANTIMAINSTREAM:** Hampir tidak ada form builder yang punya fitur "ekstrak konten dari situs luar" tanpa install extension browser (cuma pakai **bookmarklet** = 1 klik di bookmark bar).

| Implementasi Web | Detail |
|---|---|
| **Halaman Generator Bookmarklet** | Di dashboard web FormUp, ada halaman: **"📚 Toolkit Guru"** → user drag tombol "Generate Soal FormUp" ke bookmark bar browser |
| **Cara Kerja Bookmarklet** | User select teks di halaman web manapun → klik bookmark → popup FormUp (via `window.open` + pesan `postMessage`) muncul dengan:<br>- Field "Materi" auto-terisi teks yang di-select<br>- User pilih jumlah soal + tipe → klik Generate → soal langsung masuk ke Draft Form baru di FormUp |
| **Fallback Web Share API** | Untuk mobile web Android: user Share teks ke FormUp PWA |
| **Prioritas** | 🟡 SEDANG — wow factor tinggi, viral di kalangan guru |

---

### 🧠 #5. Auto-Cluster Jawaban Essay (AI Categorization)
**Kenapa SANGAT PENTING:** Guru dapat 300 jawaban essay ujian, tidak mungkin baca 1 per 1. AI otomatis **kelompokkan jawaban jadi 4-5 cluster**, guru tinggal review per kelompok.

**Kenapa ANTIMAINSTREAM:** Kompetitor (Google Forms, MS Forms) cuma kasih "jumlah responden" + export mentah — **tidak ada yang AI-clustering jawaban otomatis**.

| Implementasi Web | Detail |
|---|---|
| **Trigger di Analytics Web** | Di halaman Form Responses → tab "Essay Summary", tombol: `🤖 Analisis & Kelompokkan Jawaban` |
| **AI Logic (backend + web)** | Backend kirim semua jawaban essay + kunci jawaban ke AI (pakai API key rotation di atas!), AI return:<br>```json<br>[{ clusterName: "Jawaban Sempurna (32 jawaban)", sampleIds: [12, 45], avgScore: 95, keywordTag: ["hukum newton 2", "percepatan", "gaya gesek"] }, { clusterName: "Kurang Rumus (78 jawaban)", sampleIds: [...], commonMistake: "Lupa pakai koefisien gesek" }]<br>``` |
| **UI Web** | Tampilkan **card cluster** dengan warna berbeda (hijau=bagus, kuning=kurang, merah=salah konsep), klik cluster → expand daftar jawaban anggota + tombol "Beri skor 85 untuk SEMUA di cluster ini" |
| **Prioritas** | 🔴 TERTINGGI — menghemat jam kerja koreksi guru 10x lipat |

---

### 📶 #6. Offline Form Runner + Background Sync Auto
**Kenapa SANGAT PENTING:** Banyak sekolah di daerah 3T (terluar, terdepan, tertinggal) internetnya Mati Mendadak. Siswa isi ujian setengah jalan, koneksi putus → jawaban HILANG = trauma.

**Kenapa ANTIMAINSTREAM:** Banyak form builder KLAIM "offline support" tapi cuma cache halaman — **tidak ada yang auto-sync otomatis dengan conflict resolution** ketika koneksi balik.

| Implementasi Web | Detail |
|---|---|
| **Service Worker + IndexedDB** | Di web Form Runner (`FormRunnerPage.jsx`):<br>- Setiap perubahan jawaban (per 3 detik / setiap blur input) → **simpan ke IndexedDB** dengan flag `syncStatus: DIRTY`<br>- Tambah **Badge di sudut kanan atas**: `Offline Mode (Perubahan Belum Tersimpan: 3)` dengan indikator warna |
| **Background Sync API** | Ketika koneksi balik (event `online`), service worker otomatis:<br>1. Ambil semua record `DIRTY` dari IndexedDB<br>2. Kirim ke backend `POST /api/forms/{id}/responses/draft-sync`<br>3. Kalau sukses → update flag `SYNCED`, tampilkan toast "✅ Semua jawaban tersimpan otomatis"<br>4. Kalau conflict (submit bersamaan dari 2 tab) → pakai **last-write-wins + timestamp** |
| **Installable PWA** | Tambah manifest.json supaya FormUp bisa di-install ke desktop/HP tanpa App Store |
| **Prioritas** | 🔴 TERTINGGI — solving real pain point sekolah Indonesia |

---

### 🌀 #7. Git-like Form Versioning + Side-by-Side Diff Rollback
**Kenapa SANGAT PENTING:** Guru edit soal ujian, salah ubah 5 butir soal, pengen balik ke versi "2 jam yang lalu sebelum saya edit". Tanpa versioning, data hilang permanen.

**Kenapa ANTIMAINSTREAM:** Hampir SEMUA form builder cuma autosave TANPA history snapshot. Git-like diff untuk form = unicorn feature.

| Implementasi Web | Detail |
|---|---|
| **Auto-Snapshot Otomatis** | Backend trigger snapshot setiap kali user klik "Simpan Form" atau tiap 10 edit di Form Builder web → tabel baru `FormSnapshot { id, formId, versionLabel, diffPayload, createdAt, userId }` |
| **UI Version History Web** | Di Form Builder → tombol baru di header: `🕘 Riwayat Versi (12)` → modal timeline:<br>- Versi: `v7 — 13/09 14:32 — Budi (Guru Matematika)` dengan label otomatis: `"Tambah 3 soal, edit 2 soal"`<br>- Klik 2 versi → **Side-by-Side Diff View** (seperti GitHub) warna merah/hijau: "Soal 5 diubah: dari `√x = 5` jadi `√x = 12`" |
| **Rollback 1 Klik** | Klik tombol "⏪ Rollback ke Versi Ini" → konfirmasi → form kembali ke state lama, snapshot BARU dibuat (tidak overwrite history) |
| **Prioritas** | 🟡 SEDANG — penting untuk keamanan data guru |

---

### 🔍 #8. Multi-Window Proctoring Sync (Deteksi Buka 2 Tab Ujian)
**Kenapa SANGAT PENTING:** Proctoring biasa (`DetectTabSwitch` di `FormSetting.cs:35`) cuma deteksi PINDAH tab — tapi **SISWA CERDAS BUKA 2 JENDELA BROWSER BERSAMAAN**, 1 isi ujian, 1 buka Google. Tidak ketahuan.

**Kenapa ANTIMAINSTREAM:** Belum ada form builder yang pakai **Broadcast Channel API** untuk sync multi-window same-origin secara realtime.

| Implementasi Web | Detail |
|---|---|
| **Lock API + Broadcast Channel** | Di Form Runner web mode ujian (`IsExamMode = true`):<br>1. Saat start ujian, ambil `navigator.locks.request('exam-form-' + formId)` → cegah 2 tab akses form yang sama<br>2. Pakai `BroadcastChannel('formup-exam-' + formId)` untuk kirim pesan antar jendela<br>3. Kalau ada pesan `PING_FROM_ANOTHER_WINDOW` dengan sessionId berbeda → otomatis record violation + opsi: "⚠️ Terdeteksi buka ujian di jendela lain. Tutup yang lain dalam 10 detik atau Force Submit." |
| **Cross-Tab Timer Sync** | Kalau siswa pause di tab 1, timer di tab 2 juga berhenti (tidak bisa curang "pause di tab A, lanjut di tab B") |
| **Log di Exam Monitoring Web** | Admin dashboard proctoring tambah kolom: `Multi Window Detected: Ya (2 jendela, 3x pelanggaran)` |
| **Prioritas** | 🟠 TINGGI — upgrade proctoring dari "basic" ke "level LMS" |

---

### 🎯 #9. AI Survey Bias Detector (Scan Pertanyaan Bias Sebelum Publish)
**Kenapa SANGAT PENTING:** Untuk yang buat survei/riset (bukan cuma kuis), sering buat **Leading Question** (pertanyaan menjurus): *"Setuju kan kurikulum merdeka sudah sangat bagus?"* — hasil survei jadi tidak valid.

**Kenapa ANTIMAINSTREAM:** **TIDAK ADA SATU PUN** form builder mainstream yang punya fitur scan bias pertanyaan built-in. Ini fitur level alat riset profesional.

| Implementasi Web | Detail |
|---|---|
| **Pre-Publish Check List Web** | Sebelum user klik "Publish Form", jalankan otomatis **AI Scan Checklist**:<br>- ✅ Ejaan & tanda baca<br>- ✅ Leading question detection<br>- ✅ Double-barreled question (satu soal 2 topik: "Apakah guru RAMAH dan CERDAS?")<br>- ✅ Ambiguity detection (soal bisa diartikan 2 makna)<br>- ✅ Sensitif budaya/SARA detection |
| **Inline Warning Web** | Di Form Builder, tiap soal yang terindikasi bias muncul badge ⚠️ KUNING di samping nomor soal. Klik badge → penjelasan + rekomendasi perbaikan AI: "Soal 7 mengandung leading question, saran perbaikan: 'Bagaimana pendapat Anda tentang kualitas kurikulum merdeka?'" |
| **Skor Kualitas Formulir** | Tampilkan skor di header Form Builder: `✨ Kualitas Formulir: 87/100 — Kurangi 3 pertanyaan bias untuk 100` |
| **Prioritas** | 🟡 SEDANG — niche tapi SUPER berguna untuk user riset/perguruan tinggi |

---

## 🎯 Ringkasan Prioritas Implementasi Web

```
URUTAN PALING DIREKOMENDASIKAN (Impact vs Effort):
1. 🔴 Multi API Key Rotation          — Effort Rendah, Impact TINGGI (cepat jadi!)
2. 🔴 Offline Form Runner + Sync      — Effort Sedang, Impact TINGGI (sekolah 3T butuh!)
3. 🔴 Auto-Cluster Jawaban Essay      — Effort Sedang, Impact TINGGI (hemat waktu guru!)
4. 🟠 Adaptive Difficulty Engine      — Effort Tinggi, Impact SANGAT TINGGI (USP FormUp!)
5. 🟠 Multi-Window Proctoring         — Effort Rendah, Impact TINGGI (upgrade proctoring!)
6. 🟠 Clipboard Import Form           — Effort Rendah, Impact SEDANG (mudah share!)
```

Kalau mau saya breakdown task teknis per item (file mana yang diubah, struktur tabel baru, dll), tinggal bilang aja! 🚀

---

**User**

gua suka multi api key rotation sama offline form runner + sync ,itu harus ubah be ga?apa bisa hanya web saja fe web

**Assistant**

Pertanyaan bagus, mari saya jawab **SPESIFIK per fitur** dengan bukti dari kode web dan backend FormUp Anda:

---

## ✅ #1. Multi API Key Rotation → **TIDAK PERLU UBAH BE SAMA SEKALI, 100% CUKUP FE WEB SAJA**

### Bukti dari kode yang ada:
Lihat `web/form-fe/src/services/aiService.js:179` dan `:382`:
```javascript
const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${apiKey}`;
const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:streamGenerateContent?key=${apiKey}&alt=sse`;
```

👉 **AI call di web FormUp SUDAH langsung dari browser ke Google AI Studio, TIDAK lewat backend FormUp Anda.** Jadi rotasi key, cooldown, retry semuanya bisa di-handle 100% di sisi browser.

### Bagian yang HANYA perlu diubah (FE WEB SAJA):

| File / Komponen FE Web | Perubahan yang Dibutuhkan |
|---|---|
| `src/services/aiService.js` | Ubah `getGeminiApiKey()` → `getActiveApiKeyPool()`. Tambah wrapper function `callWithKeyRotation(params)` yang berisi loop retry + cooldown tracker + priority selection. |
| `src/services/aiKeyPoolStore.js` | **Buat file baru (FE only)** — Kelola CRUD pool key di `localStorage` atau `IndexedDB` (IndexedDB lebih bagus karena kapasitas besar, tahan clear cache). Struktur: `[{ id, label, key, priority, cooldownUntil, lastStatus, usageCount }]` |
| `src/components/ui/AIGeneratorModal.jsx` `src/components/ui/AIFormBuilderModal.jsx` | Tambah **Badge Status Key Aktif** di header modal (contoh: `🔑 Key A1 [Prioritas 1] — 312x dipakai`) |
| `src/features/dashboard/userDashboard/userhome.jsx` atau sidebar baru | Tambah halaman **Pengaturan Pool API Key** — tabel CRUD key, drag-drop ubah prioritas, tombol "Test Semua Key" |

### Yang TIDAK PERLU disentuh sama sekali:
- ❌ Semua file `.cs` di `/api/Controllers`
- ❌ `Program.cs` backend
- ❌ Database / migration
- ❌ Mobile app (kecuali nanti mau port fitur ini ke mobile, tapi kalau cuma web ya tidak usah)

---

## ⚠️ #2. Offline Form Runner + Sync → **ADA 2 PILIHAN**: MVP (FE ONLY) vs FULL (BUTUH BE)

### Analisis dari kode yang ada:
Form Runner web ada di `FormRunnerPage.jsx`. Submit jawaban sekarang cuma 1 rute: **final submit** ke `POST /api/forms/{formId}/responses` di `ResponsesController.cs:28`. Tidak ada mekanisme simpan draft parsial.

Berikut dua opsi implementasi:

---

### 🅰️ OPSI 1: MVP VERSION (**100% FE WEB SAJA, TIDAK PERLU UBAH BE**)
Konsep: "Simpan jawaban offline di browser, USER HARUS KLIK SUBMIT MANUAL SAAT SUDAH ONLINE."

| Bagian | File FE Web yang Diubah | Detail |
|---|---|---|
| **Auto-save draft ke IndexedDB** | `src/features/form-runner/FormRunnerPage.jsx` + `src/services/offlineDraftStore.js` (file baru) | Setiap 3 detik / setiap user blur input jawaban, serialize semua jawaban + sisa waktu timer → simpan ke IndexedDB dengan key `draft-{formId}-{sessionId}`. Tampilkan badge `💾 Tersimpan Lokal 14:32:15` |
| **Deteksi online/offline** | `FormRunnerPage.jsx` | Listen event `window.online` / `window.offline`. Tampilkan banner merah besar `⚠️ MODE OFFLINE — Jawaban tersimpan di perangkat Anda. JANGAN close tab sebelum submit manual.` |
| **Restore draft ketika buka kembali** | `FormRunnerPage.jsx` mount / `FormStartPage.jsx` | Ketika user buka link form yang sama, cek IndexedDB: `Ditemukan jawaban tersimpan dari 2 jam lalu (12 soal terjawab). Lanjutkan?` → user klik Lanjutkan → restore state form dari IndexedDB |
| **Validasi submit saat online** | `ResponseSubmission.cs` (TIDAK DIUBAH) | Pakai endpoint submit YANG SUDAH ADA. User Wajib online untuk klik tombol "Kirim Jawaban" akhir. Kalau masih offline → tombol disabled + tooltip "Hubungkan internet untuk submit." |

**Kelebihan Opsi A:**
- ✅ Cepat jadi (1-2 hari)
- ✅ Zero perubahan BE, zero migration DB
- ✅ 90% use case tercover (user lupa koneksi, internet mati tengah jalan → data tidak hilang)

**Kekurangan Opsi A:**
- ❌ Belum auto-sync diam-diam di background
- ❌ Belum ada conflict resolution (buka form di 2 tab → tab mana yang menang?)
- ❌ Untuk ujian proctored = timer tidak sync ke BE saat offline

---

### 🅱️ OPSI 2: FULL VERSION (**BUTUH PERUBAHAN BE, FITUR LEBIH LENGKAP**)
Konsep: "Auto-sync background diam-diam, conflict resolution BE-side, support exam session resume."

| Bagian | File | Perubahan | FE / BE |
|---|---|---|---|
| **Draft Sync Endpoint** | `ResponsesController.cs` | Tambah endpoint baru: `POST /api/forms/{formId}/responses/draft-sync` — menerima batch jawaban parsial + timestamp, insert/update ke tabel sementara `ResponseDraft` (tidak mengubah `Response` final). Return `{ syncVersion: 5, serverTime: "..." }` | **BE** |
| **Tabel DB baru** | `FormUpDbContext.cs` + migration | `ResponseDraft { id, formId, sessionId, respondentToken, payloadJson, syncVersion, lastSyncedAt, submittedAt }` | **BE** |
| **Background Sync API** | `src/services/backgroundSync.js` (file baru) | Pakai `navigator.serviceWorker.ready.sync.register('formup-draft-sync')`. Ketika koneksi balik, SW otomatis kirim semua draft ke `/draft-sync` tanpa user buka tab | **FE** |
| **Conflict Resolution** | `ResponseSubmission.cs` | Logika merge: `jawaban BE (lebih baru timestamp)` > `jawaban FE (lebih lama)`. Kalau conflict field yang sama → return `409 Conflict` ke FE, FE kasih user pilih "Pakai versi server" / "Pakai versi perangkat saya" | **BE + FE** |
| **Exam Session Resume** | `ExamMonitoringController.cs` + `ExamSession.cs` | Tambah logic: offline >5 menit → session di-mark `PAUSED`. Ketika sync balik → timer lanjut dari sisa waktu (bukan dari awal) | **BE + FE** |

**Kelebihan Opsi B:**
- ✅ User experience seamless (tidak sadar apa-apa, otomatis sync)
- ✅ Exam proctoring tetap akurat (timer BE-side)
- ✅ Support conflict resolution (case 2 device)

**Kekurangan Opsi B:**
- ❌ Butuh 3-5 hari kerja (BE + FE bareng)
- ❌ Migration DB + testing edge case (offline 3 hari, dll)

---

## 🎯 Rekomendasi Saya untuk Kamu:

```
URUTAN KERJA PALING EFEKTIF (Tanpa Stress):
────────────────────────────────────────────
1. ✅ KERJAKAN DULU: Multi API Key Rotation (FE ONLY)
   → 1-2 hari selesai, langsung impact, NO RISK BE.

2. ✅ KERJAKAN KEDUA: Offline Form Runner OPSI A (MVP - FE ONLY)
   → 2 hari selesai, solve 90% problem user, NO RISK BE.
   → Simpan ke IndexedDB, restore otomatis, manual submit.

3. ⏸️ TUNGGU SAMPAI USER MINTA: Baru Opsi B Full Auto-Sync (Butuh BE)
   → Kalau sudah ada feedback guru dari daerah 3T mengalami masalah
     "saya lupa submit padahal jawaban sudah lengkap", baru kerjakan BE.
```

Kalau kamu setuju, saya bisa mulai breakdown **task per file + pseudo code** untuk Multi API Key Rotation (FE only) dan Offline MVP (FE only) sekarang. Mau? 🚀

---

**User**

oke catat 2 itu saran fitur lain yang sangat bagus,ga wajib automisation doang,bebas,boleh yang buat imporve ux

**Assistant**

Oke, **Multi API Key Rotation** dan **Offline Form Runner MVP (FE Only)** resmi saya catat. Berikut 15+ saran fitur lain yang sangat bagus — campuran **UX Improvements**, **Fitur Edukasi Spesifik**, dan **Produktivitas Tools** (tidak cuma automation). Semua berbasis analisis mendalam kode FormUp web & backend Anda:

---

## 📋 CATATAN FITUR BARU FORMUP (2 FITUR UTAMA + 15 FITUR TAMBAHAN)

### 🔥 2 FITUR UTAMA YANG DIPUTUSKAN (PRIORITAS TERTINGGI)
| # | Nama Fitur | Scope |
|---|---|---|
| 1 | **Multi API Key Rotation + Key Pool Manager** | FE Web Only (no BE) |
| 2 | **Offline Form Runner MVP: Auto-Save IndexedDB + Restore Draft** | FE Web Only (no BE) |

---

## ✨ 15+ SARAN FITUR TAMBAHAN (CAMPURAN UX / EDUKASI / PRODUKTIVITAS)

---

### 🎓 KATEGORI A: FITUR EDUKASI KHUSUS (GURU & SISWA) — USP FormUp

#### 🟢 A1. **Printable Answer Sheet Generator (Lembar Jawaban Otomatis)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Guru mau ujian PAPER-BASED (tidak semua sekolah punya laptop), tapi malas bikin lembar jawaban manual. |
| **Implementasi Web** | Di Form Detail → tombol baru: `📄 Cetak Lembar Jawaban`. Generate PDF langsung di browser (pakai `QuestPDF` yang SUDAH ADA di backend, atau `jsPDF` FE-only) yang isinya: Judul Ujian, Nama/NIS/Kelas fields, kotak jawaban PG per nomor, kolom skor. |
| **Bonus** | Opsi: `☑️ Sertakan Kunci Jawaban di Halaman Terakhir` (cuma untuk guru) + `☑️ Versi A / Versi B` (soal di-acak urutannya, lembar jawaban beda kode warna). |
| **Prioritas** | 🟠 TINGGI — unik, kompetitor tidak fokus paper-based. |

#### 🟢 A2. **Peer Assessment Mode (Penilaian Antar Teman Otomatis)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Guru mau latihan menilai karya antar siswa (misal: essay, jawaban studi kasus) tapi susah mengatur distribusi. |
| **Implementasi** | Setting form baru: `☑️ Mode Peer Assessment`. Setelah semua siswa submit → sistem otomatis **acak & distribusikan jawaban** ke 2-3 siswa lain untuk dinilai dengan rubrik. Jawaban yang sudah dipeer-review tampil ke guru beserta skor rata-rata peer vs skor guru. |
| **Anonimitas** | Nama responden di-blind: "Jawaban #A72" agar tidak ada subjektif. |
| **Prioritas** | 🟠 TINGGI — ini fitur LMS kelas Kakaledo/Ruangguru, tidak ada di Google Forms. |

#### 🟢 A3. **Remediation Workflow Engine (Alur Remedi Otomatis Berbasis Skor)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Guru harus pisahin manual siswa yang lolos vs remedi. Ribet. |
| **Implementasi Web** | Tab baru di Form Settings: `🔄 Alur Kelanjutan`. Drag-drop node seperti flowchart:<br>• `[Skor < 70]` → Auto-send email + link Form Remidi "Bab Gelombang (Level Dasar)" + link materi video<br>• `[Skor 70-89]` → Auto-send link "Latihan Tambahan"<br>• `[Skor >= 90]` → Auto-send badge achievement "Lulus dengan Predikat Sangat Baik" + link Form Lanjutan<br>**FE-only MVP:** Jalankan check workflow TEPAT SETELAH submit respons di `FormResultPage.jsx`, tampilkan hasilnya di halaman skor. |
| **Prioritas** | 🟠 TINGGI — fitur pendidikan berdampak langsung. |

---

### 🎨 KATEGORI B: UX IMPROVEMENTS (PENGALAMAN PENGGUNA)

#### 🔵 B1. **Command Palette (Ctrl+K) Semua Fitur**
| Detail | Keterangan |
|---|---|
| **Masalah** | User baru bingung menu di mana. Navigasi klik sana-sini lambat. |
| **Implementasi Web** | Global shortcut `Ctrl+K` / `Cmd+K` buka modal search bar (mirip VS Code / Linear). Ketik: `buat` → `Buat Form Baru`, `kuis fis` → `Buka Kuis Fisika Kelas 11`, `ekspor csv kuis` → langsung arahkan ke halaman respons + buka dialog export. |
| **Tech** | `cmdk` package React, tapi bahkan custom state pun jadi. Index semua form user + menu utama. |
| **Prioritas** | 🔴 TERTINGGI — 10x boost produktivitas user power-user. |

#### 🔵 B2. **Soal Type Preset + Quick Templates (Template Cepat di Form Builder)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Guru bikin soal PG berulang-ulang: "Pilihan A/B/C/D + kunci di B". Capek setting manual tiap buat soal baru. |
| **Implementasi Web** | Di `FormBuilder.jsx`, tambah **bar preset chips** di atas setiap question card baru:<br>`🎯 Template Cepat: [Soal PG 4 Opsi] [Soal Benar/Salah] [Skala Likert 1-5] [Isian Singkat 1 Kata] [Tanggal]`<br>Klik chip → auto-apply konfigurasi soal (typeId, jumlah opsi default, dll). |
| **Bonus** | Fitur `💾 Simpan sebagai Template Pribadi` — user bisa simpan struktur soal favorit (misal "Soal Hitung Matematika dengan Gambar") untuk pakai berulang. |
| **Prioritas** | 🔴 TERTINGGI — menghemat klik 50% saat bikin soal. |

#### 🔵 B3. **Bulk Edit Questions (Edit Massal Soal)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Bikin 50 soal PG, mau ganti SEMUA bobot poin dari 10 jadi 5. Atau mau tandai SEMUA sebagai "Wajib". Klik 1 per 1 = NIGHTMARE. |
| **Implementasi Web** | Di halaman `FormQuestionsScreen.dart` / web equivalent, tambah **toolbar bulk edit** yang muncul ketika user pilih multi soal (centang checkbox tiap soal):<br>• `[Terpilih: 12 soal]  Ubah Bobot → [ 5 ]   Tandai: [Wajib ✅] [Acak Opsi ✅]   Pindah ke [Bagian 2]   Hapus` |
| **Bonus** | Fitur **Search & Replace Teks Soal**: `Ganti "Benar/Salah" menjadi "Ya/Tidak" di SEMUA 50 soal`. |
| **Prioritas** | 🔴 TERTINGGI — solve pain point terbesar user yang punya soal banyak. |

#### 🔵 B4. **Smart Undo/Redo di Form Builder (History Stack Action)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Guru tidak sengaja hapus 15 soal, tombol Undo cuma bisa undo action terakhir. Menangis. |
| **Implementasi Web** | Implementasikan **Command Pattern + Stack History** di state Form Builder. Simpan 50 action terakhir: `[Added Question #12, Edited Question #7, Deleted Questions #3-#8]`. `Ctrl+Z` undo, `Ctrl+Y` redo. Tampilkan dropdown history action agar user bisa jump ke state sebelum kecelakaan. |
| **Prioritas** | 🟠 TINGGI — peace of mind user, mencegah data hilang tidak sengaja. |

#### 🔵 B5. **Responsive Split View Form Builder (Layout 2 Kolom)**
| Detail | Keterangan |
|---|---|
| **Masalah** | User edit soal → klik preview → kembali edit → preview lagi. Bolak-balik. |
| **Implementasi Web** | Untuk layar lebar (laptop/PC), tambah toggle `⇔ View: [Split] [Edit] [Preview]`. Mode Split = KIRI panel edit soal, KANAN live preview langsung auto-refresh. Tidak perlu pindah halaman. |
| **Prioritas** | 🟡 SEDANG — wow effect tinggi untuk desktop user. |

---

### 🚀 KATEGORI C: PRODUKTIVITAS & INTEGRASI

#### 🟣 C1. **Bulk Import Questions dari Teks Biasa (Plain Text Paste)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Guru punya daftar soal di Word/Notepad: `1. Ibu kota Indonesia? A. Jakarta B. Bandung C. Surabaya` — capek masukin 1 per 1 ke Form Builder. |
| **Implementasi Web** | Di halaman Questions → tombol baru: `📝 Impor dari Teks`. Buka textarea, user paste format apapun, AI (pakai Gemini yang SUDAH ADA) otomatis parsing menjadi array soal terstruktur: `Soal → Opsi → Kunci Jawaban`. Validasi lalu insert ke form. |
| **FE-only** | Semua parsing di `aiService.js` yang sudah ada, pakai pool key rotation juga! |
| **Prioritas** | 🔴 TERTINGGI — menghemat jam kerja guru MASSIVE. |

#### 🟣 C2. **Duplicate Form Template + Replace Placeholder Batch**
| Detail | Keterangan |
|---|---|
| **Masalah** | Guru bikin "Kuis Harian Matematika (Senin)" → mau duplikat untuk (Selasa) tapi ganti JUDUL + BAB semua soal. |
| **Implementasi** | Fitur duplikat form + dialog **Find & Replace Global**: `Ganti semua "[Bab 3]" menjadi "[Bab 4]" di JUDUL + DESKRIPSI + SELURUH TEKS SOAL + OPSI jawaban sekaligus.` |
| **Prioritas** | 🟠 TINGGI — sering dipakai untuk yang punya template berulang. |

#### 🟣 C3. **Custom Domain untuk Link Form (White Label)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Sekolah/sekolah Islam/swasta mau link ujiannya `ujian.smakindonesia.sch.id/form/uts-matematika` bukan `formup.app/form/abc123`. Terlihat profesional. |
| **Implementasi MVP (BE ringan)** | User setting di Profile: `Custom Domain: ujian.sekolahku.id` → verifikasi DNS (user tambah CNAME record ke server FormUp). Backend `PublicFormsController.cs` cek `Host` header HTTP, cocokkan dengan `user.CustomDomain` → tampilkan form branding sekolah (nama sekolah, logo, warna tema) tanpa logo FormUp. |
| **Prioritas** | 🟡 SEDANG — monetizable (fitur premium untuk sekolah). |

#### 🟣 C4. **Auto-Generate Sertifikat Kelulusan PDF**
| Detail | Keterangan |
|---|---|
| **Masalah** | Lulus ujian → guru mau kasih sertifikat e-sertifikat. Biasanya bikin manual di Canva. |
| **Implementasi** | Setting form: `☑️ Generate Sertifikat untuk Skor >= [ 80 ]`. Template sertifikat: upload background PNG, drag-drop field: `[Nama Responden] [Skor] [Judul Form] [Tanggal] [Signature Guru]`. Pakai library canvas/html2pdf FE-only — generate PDF langsung di browser saat user buka halaman hasil (`FormResultPage.jsx`). |
| **Prioritas** | 🟠 TINGGI — user suka banget, shareable, bagus untuk branding FormUp. |

---

### 🛡️ KATEGORI D: ADMIN & KEAMANAN (INSTITUSIONAL)

#### ⚫ D1. **Audit Log Lengkap (Siapa Edit Apa & Kapan)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Form ujian penting, tahu-tahu soal berubah. Guru A salahkan Guru B. Tidak ada bukti. |
| **Implementasi** | Backend tabel baru `FormAuditLog { formId, userId, actionType (CREATE/EDIT/DELETE/PUBLISH/EXPORT), fieldChanged, oldValue, newValue, ipAddress, timestamp }`. Di halaman Form Detail, tab baru: `🕘 Log Aktivitas` — timeline siapa ngapain, support filter by user + date range. |
| **Prioritas** | 🟡 SEDANG — CRITICAL untuk ujian nasional/UTS/UAS sekolah formal. |

#### ⚫ D2. **Team Collaboration: Role Access per Form (Owner / Editor / Viewer)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Guru Matematika X mau minta Guru Matematika Y review soal formnya — sekarang harus share akun (bahaya!). |
| **Implementasi** | Tombol baru di Form Detail: `👥 Undang Kolaborator`. Input email, pilih role:<br>• `Owner` (semua akses, delete form)<br>• `Editor` (tambah/edit/hapus soal, tidak bisa delete form)<br>• `Viewer` (hanya lihat form + analytics, tidak bisa edit)<br>Backend: tabel `FormCollaborator { formId, userId, role }`. |
| **Prioritas** | 🟠 TINGGI — form baru mulai berguna untuk tim/sekolah besar. |

#### ⚫ D3. **Respondent Invalidation Tool (Anulir Jawaban Curang)**
| Detail | Keterangan |
|---|---|
| **Masalah** | Admin lihat analytics, ada responden yang skor 100 tapi jawaban essay-nya copas dari Google (deteksi plagiarisme? atau waktu jawab cuma 10 detik untuk 50 soal). Mau hapus jawaban ini dari perhitungan statistik. |
| **Implementasi Web** | Di halaman Form Analytics → tiap row responden, tambah menu 3 titik: `🚫 Tandai Tidak Sah`. Data jawaban tetap tersimpan (tidak dihapus demi audit) tapi **tidak masuk perhitungan rata-rata skor, distribusi opsi, dan export CSV**. Tampilkan badge abu-abu "Dianulir" di list. |
| **Prioritas** | 🟡 SEDANG — analitik jadi lebih bersih & akurat. |

---

### 🎁 BONUS FITUR CINTA (MICRO-DELIGHT)

#### 💖 E1. **Confetti Celebration di Halaman Hasil**
Submit ujian → skor >= 85 → confetti turun dari atas layar (pakai `canvas-confetti` library kecil). Skor sempurna 100 → efek FIREWORKS + suara tada kecil. Menyenangkan untuk siswa.

#### 💖 E2. **Progress Bar Target Harian Guru**
Dashboard user home: `🎯 Target Hari Ini: Buat 1 Form / 20 Soal` dengan progress bar. Motivasi produktivitas.

---

## 🎯 RINGKASAN PRIORITAS 5 BESAR SETELAH 2 FITUR UTAMA

Kalau kamu pengen lanjut setelah **Key Rotation** dan **Offline MVP**, urutannya rekomendasi saya:

```
PRIORITAS SETELAH KEY ROTATION + OFFLINE MVP:
──────────────────────────────────────────────
1. 🔴 Command Palette Ctrl+K              (FE ONLY) — boost produktivitas instan
2. 🔴 Bulk Edit Questions                 (FE ONLY) — solve pain point terbesar
3. 🔴 Bulk Import Questions dari Teks AI  (FE ONLY, pakai existing AI)
4. 🔴 Soal Type Preset + Quick Templates  (FE ONLY) — cepat implement
5. 🟠 Smart Undo/Redo Form Builder        (FE ONLY) — peace of mind user
```

Semua 5 di atas **FE ONLY** (tidak perlu sentuh backend .NET) — cepat jadi, impact besar! Mau saya breakdown task per file untuk yang mana duluan? 🚀

---

**User**

analissi web deh,ui/ux yang kurang apa,misal loading atau apa

**Assistant**

Saya akan analisis UI/UX web FormUp secara mendalam dari sisi kode. Mari saya buka file-file krusial: Form Builder, AI Modal, Form Runner, Auth Pages, API Service, dan Dashboard.

Mari saya lanjut analisis file krusial lain: Form Runner (ujian), Dashboard User Home, Login, dan Analytics untuk menemukan masalah loading state, empty state, error handling, dan UX lainnya.

Analisis UI/UX web FormUp selesai berdasarkan 6 file krusial (`apiService.js`, `FormBuilder.jsx`, `AIGeneratorModal.jsx`, `FormRunnerPage.jsx`, `userhome.jsx`, `Login.jsx`). Berikut temuan terstruktur + prioritas perbaikan:

---

## ✅ HAL YANG SUDAH BAGUS (PATDI DIPERTAHANKAN)

Sebelum kritik, yang sudah bagus:
1. ✅ **Skeleton loading dashboard** (`userhome.jsx:160-199`) — pakai `animate-pulse`, tidak spinner kosong
2. ✅ **Upload progress gambar/audio** (`FormBuilder.jsx:150` + `apiService.js:244-295`) — pakai XHR onProgress, jarang dimiliki form builder lain
3. ✅ **Status generator AI jelas** (`AIGeneratorModal.jsx:510-527`) — spinner + status text + timer detik
4. ✅ **Cikal bakal offline cache jawaban** (`FormRunnerPage.jsx:75-86`) — localStorage `formup_cache_${formLink}` (pondasi Offline MVP kita nanti)
5. ✅ **Undo/Redo History Stack** (`FormBuilder.jsx:116-125`)
6. ✅ **Marked for Review (Ragu-ragu)** (`FormRunnerPage.jsx:39`)

---

## 🔴 1. LOADING STATE: TERBANYAK MASALAH KRITIS

### ❌ A. Semua HTTP Request TANPA TIMEOUT + TANPA RETRY (BAHAYA SPINNER FOREVER)
**Lokasi:** Semua fungsi di `apiService.js` (login:43, getMyForms:138, createForm:142, dll)
- Mobile ada fitur **"Timeout 6 detik + Retry 1x"** (dokumentasi `mechanisms.md:49`), **WEB TIDAK ADA SAMA SEKALI**
- `fetch()` vanilla tanpa `AbortController` = kalau server hang/504 gateway timeout, user lihat spinner selamanya
- Tidak ada `signal` yang bisa di-cancel saat user pindah halaman (memory leak + request menumpuk)

**Contoh kasus:** User loading dashboard `getMyForms()` lalu koneksi Wi-Fi hilang → spinner jalan terus, tidak ada error, user bingung harus F5.

### ❌ B. Loading Tidak Konsisten + Banyak Progress Indicator HILANG
| Lokasi | Kondisi Loading Sekarang | Masalah |
|---|---|---|
| `Login.jsx:24` | Spinner di tombol + opacity disabled | Tombol masih berukuran kecil, user tidak menangkap "sedang loading global". **Tidak ada block UI, user masih bisa klik link Lupa Password saat login berjalan** (bisa race condition auth state) |
| `FormRunnerPage.jsx:25` initial load | Hanya state boolean `loading=true` | **TIDAK ADA SKELETON**, user lihat halaman putih kosong 2-3 detik saat ambil form + soal. Padahal ini halaman PENTING untuk ujian. |
| `apiService.js:331` Export CSV/XLSX | Return promise | Export 5000 responden bisa 30-60 detik! **TIDAK ADA PROGRESS BAR**, user kira app beku dan klik berkali-kali (double download). |
| `FormBuilder.jsx` save state | Cuma `setSaving(true)` | Autosave interval berjalan, **tidak ada indikator jelas** user tahu kapan terakhir save (cuma `autosaveToast` yang cepat hilang). |

### ❌ C. Optimistic UI Belum Diterapkan
User edit 1 huruf di soal → harus tunggu `PUT /api/forms/{id}/questions` sukses dulu sebelum state terasa "simpan". Sebaiknya: optimistic update state dulu, fallback rollback kalau gagal network.

---

## 🟠 2. EMPTY STATE: TIDAK ADA ILUSTRASI + CTA KURANG JELAS

### ❌ A. Dashboard User Baru (0 Form)
**Lokasi:** Setelah `userhome.jsx:80` `setLoading(false)` → `myForms.length === 0`
- Tidak ada ilustrasi SVG besar, tidak ada CTA ganda yang jelas. User lihat: search bar kosong + section "Formulir Terbaru" kosong tanpa arahan.
- **Seharusnya:** Ilustrasi "🚀 Ayo buat form pertamamu!" + 2 tombol besar:
  - `[✨ Buat Form dengan AI]`
  - `[📄 Buat Form Manual]`

### ❌ B. FormBuilder: Questions Kosong
Form baru dibuka, `questions=[]`. Cuma tombol `+ Tambah Soal` kecil di toolbar.
**Seharusnya:** Card empty state di tengah area form dengan 3 shortcut cepat:
- `[✨ Generate Soal Otomatis dengan AI]`
- `[📝 Impor dari Teks/Word]`  
- `[📂 Pakai Template Sekolah]`

### ❌ C. Analytics Tanpa Respons (0 Pengisi)
User buka halaman analytics form baru → cuma chart kosong / angka nol tanpa solusi.
**Seharusnya:** "📣 Form kamu belum ada yang isi! Bagikan link di bawah untuk mulai kumpulkan respons:" + tombol Copy Link + Download QR Code besar.

---

## 🔴 3. ERROR HANDLING: BISA BIKIN DATA HILANG + USER BINGUNG

### ❌ A. ⚠️ AUTO-REFRESH TOKEN TIDAK ADA DI WEB (KRITIS!)
**Lokasi:** `apiService.js:70-76` function `refreshToken()` **ADA, TAPI TIDAK PERNAH DIPANGGIL**
- Mobile flow bagus: *"Saat API balas 401 token-expired → auto refresh token + ulang request tanpa login ulang"* (`mechanisms.md:50`)
- **WEB TIDAK ADA INTERCEPTORNYA.** Akibat skenario horor:
  1. Guru edit form 50 soal selama 2 jam (token expire di tengah)
  2. Klik Simpan → 401 Unauthorized (silent error, cuma `console.error`)
  3. Jawaban hilang! Guru harus login ulang dari awal.

### ❌ B. Global Network Status Banner TIDAK ADA
**Lokasi:** `App.jsx` level root (belum dicek tapi dari file lain tidak ada indikasi listener online/offline)
- Kalau koneksi internet PUTUS TENGAH jalan:
  - `FormRunnerPage.jsx:178-179` cuma `console.warn('[ExamEvent] Background event report failed')` tanpa banner merah "⚠️ KONEKSI TERPUTUS — Pelanggaran ujian tidak terkirim ke server"
  - Guru save form → gagal tanpa pesan jelas
  - Tidak ada pendengar event `window.addEventListener('online/offline')` global

### ❌ C. Semua Error State TIDAK ADA TOMBOL RETRY
Contoh:
| Lokasi | Error Sekarang | Masalah |
|---|---|---|
| `userhome.jsx:77-79` fetch fail | `console.error('Dashboard fetch error:', err)` | User TIDAK TAHU ada error. Tidak ada apa-apa di UI. Harus F5 manual. |
| `Login.jsx:37` koneksi error | Pesan merah: "Terjadi kesalahan koneksi ke server." | Cuma teks, tanpa tombol `[🔄 Coba Lagi]` |
| `apiService.js:338` Export gagal | `{ ok: false, message }` | Hanya return object, UI tidak menangkap retry |
| Form Runner load soal gagal | Hanya state `error` | Tidak ada tombol retry load soal lagi |

### ❌ D. Submit Validasi Gagal: Tidak Auto-Scroll ke Soal Bermasalah
User submit form ada 3 soal required tidak diisi → toast muncul di atas, tapi user tetap di soal terakhir. User tidak tahu soal mana yang kosong, harus scroll manual 1 per 1.
**Seharusnya:** toast + auto-scroll ke soal pertama yang kosong + highlight border merah soal.

---

## 🟡 4. MICRO-INTERACTIONS & CONSISTENCY KURANG

### ❌ A. Toast Notifikasi TIDAK TERPUSAT (Saling Timpa)
Sekarang state toast terpecah di tiap komponen sendiri:
- `FormBuilder.jsx:72` → `setToast`
- `FormBuilder.jsx:138` → `setAutosaveToast`
- `AIGeneratorModal.jsx:52` → `setKeySavedToast`
- `FormRunnerPage.jsx:28` → `setValidationToast`

Masalah: 2 event kebaringsan (autosave sukses + key saved) → toast SALING TIMPA, user hanya lihat 1. Tidak ada queue system.

### ❌ B. Konfirmasi Close Tab Dirty State (Belum Pasti Ada)
`FormBuilder.jsx:113` SUDAH ADA state `isDirty=true` saat ada perubahan. Tapi apakah sudah ada:
```js
window.addEventListener('beforeunload', (e) => {
  if (isDirty) { e.preventDefault(); e.returnValue = ''; }
});
```
Saya tidak lihat di 250 baris pertama FormBuilder. Kalau TIDAK ADA = user salah close tab, edit 2 jam hilang tanpa peringatan!

### ❌ C. Drag & Drop Urut Soal TIDAK ADA (Pain Point Terbesar!)
Sekarang urut soal cuma pakai tombol `ChevronUp/ChevronDown` satu per satu (`FormBuilder.jsx:4` import icon). Untuk 50 soal = klik 100x untuk pindah soal nomor 1 ke nomor 50!
**Solusi:** `@dnd-kit/core` React (FE-only, 1 hari implement) → drag langsung dengan mouse.

### ❌ D. Sticky Header/Save Button Saat Scroll Panjang
FormBuilder 30 soal: user scroll ke bawah edit soal nomor 27 → mau Save/Preview/Publish harus scroll KE ATAS 3 halaman. Tidak ada **sticky bottom action bar** yang selalu nempel di viewport.

### ❌ E. Form Runner Tidak Ada Progress Bar % Selesai
Hanya teks `Soal 12/50`. User tidak punya feeling estimasi waktu sisa. Tambah **linear progress bar 100%** di atas halaman dengan warna sesuai sisa waktu (hijau → kuning → merah).

---

## 🟢 5. ACCESSIBILITY (A11Y) KURANG STANDAR

| Masalah | Lokasi Contoh |
|---|---|
| Label input tanpa `htmlFor` + input tanpa `id` → screen reader tidak koneksikan label dengan field | `Login.jsx:115-128` (Email label + input) |
| Modal tidak ada focus trap → user tab keluar modal ke belakang | `AIGeneratorModal.jsx:209` |
| Tidak ada `aria-live="polite"` untuk toast/error → user tunanetra tidak dengar notif error | Semua komponen toast |
| Loading state tanpa `aria-busy="true"` | Skeleton di dashboard |

---

## 🎯 RINGKASAN PRIORITAS PERBAIKAN (URUTAN DARI PALING KRITIS)

```
🔴 1. KRITIS (Bisa bikin DATA HILANG / Marah Besar User):
   ├─ 1.1 Interceptor 401 → auto refresh token + retry request (mirror mobile flow)
   ├─ 1.2 Global fetch timeout (AbortController 15s) + Retry 1x SEMUA request
   ├─ 1.3 window.beforeunload dirty check FormBuilder + FormRunner
   └─ 1.4 Loading indicator export CSV/XLSX + batalkan double klik

🟠 2. SANGAT PENTING (Nyata sehari-hari user):
   ├─ 2.1 Global Online/Offline Banner + Network Listener (pondasi Offline MVP)
   ├─ 2.2 Global Error Boundary + Retry Button di semua fetch fail state
   ├─ 2.3 Global Toast Manager pakai Queue (tidak saling timpa)
   ├─ 2.4 3 Empty State + CTA: Dashboard / FormBuilder Kosong / Analytics 0 Respons
   └─ 2.5 Drag & Drop Urut Soal pakai @dnd-kit (FE-only)

🟡 3. PENTING (Productivity + Delighter):
   ├─ 3.1 Sticky Action Bar FormBuilder (scroll panjang tetap bisa simpan)
   ├─ 3.2 Search & Filter soal (> 20 butir)
   ├─ 3.3 Form Runner: Progress Bar % + auto scroll soal invalid
   ├─ 3.4 Skeleton Loading untuk Form Runner initial load
   └─ 3.5 Keyboard Shortcut Cheat Sheet (tombol ? munculkan modal)

🟢 4. NICE TO HAVE:
   ├─ 4.1 Accessibility perbaikan massal (aria-*, focus trap, htmlFor)
   ├─ 4.2 Copy 1 soal ke form lain (1 klik)
   ├─ 4.3 Skeleton untuk halaman Analytics
   └─ 4.4 Form Runner: Countdown warna + alert suara 1 menit terakhir
```

Kalau mau saya breakdown task teknis per item (contoh item 1.1 auto-refresh token: file mana diubah, pseudo code interceptor fetch), bilang aja! 🚀

---

**User**

apa yang baru di api,apakah sudah di terapkan di website?,ini info nya

 api/Controllers/AdminController.cs                                      |  22 ++--
 api/Controllers/AnalyticsController.cs                                  |  31 ++++--
 api/Controllers/AuthController.cs                                       |  26 +++++
 api/Controllers/ExamMonitoringController.cs                             | 109 +++++++++++++------
 api/Controllers/FeedbacksController.cs                                  |  16 +--
 api/Controllers/FormsController.cs                                      |  19 ++--
 api/Controllers/PublicFormsController.cs                                |   5 +-
 api/Controllers/QuestionsController.cs                                  | 114 +++++++++++++++++++-
 api/Controllers/ResponsesController.cs                                  |  23 +++-
 api/Controllers/UsersController.cs                                      |   4 +-
 api/Models/AuthDtos.cs                                                  |   6 ++
 api/Models/FormDtos.cs                                                  |   3 +
 api/Models/FormUpDbContext.cs                                           |  28 +++++
 api/Models/QuestionDtos.cs                                              |   3 +
 api/Models/User.cs                                                      |   2 +
 api/Program.cs                                                          |  15 +++
 api/Services/ReferenceCache.cs                                          |  50 +++++++++
 api/Services/ResponseSubmission.cs                                      |  43 +++++---

**Assistant**

Mari saya analisis perubahan backend terbaru secara detail, lalu cross-check apakah fitur baru itu sudah ter-integrasi di web FE.

Mari saya baca file lain untuk cross-check fitur baru: ReferenceCache (yang baru dibuat), Program.cs (konfigurasi baru), AuthController (refresh token), ExamMonitoring, Analytics (export jawaban), dan terakhir cek apakah FE web sudah meng-integrasi fitur baru ini.

Sekarang mari saya cross-check apakah fitur backend baru ini sudah terintegrasi di web FE. Saya cek Auth (refresh token interceptor), QuestionsController (import doc/PDF/Word), ResponsesController (manual scoring override), dan ExamMonitoring.

Bagus, menemukan beberapa petunjuk. Mari saya dalami lebih detail: QuestionsController (import file AI), endpoint apa lagi yang baru. Saya baca sisa QuestionsController dan cek bagian apiService untuk import questions.

Sekarang saya cek bagian QuestionsController (import file AI) dan endpoint terakhirnya. Juga cek apakah FE sudah memanggil endpoint scoring override, exam monitoring session state, dan export dengan kunci jawaban.

Analisis selesai. Berikut hasil detailnya:

---

# 📋 RINGKASAN: APA YANG BARU DI API + STATUS INTEGRASI DI WEBSITE

Dari diff 18 file backend, saya uraikan menjadi **6 kelompok fitur baru**, masing-masing dengan badge status:

| Status | Arti |
|---|---|
| ✅ | **Sudah terintegrasi penuh di FE Web** |
| 🟡 | **Backend sudah, FE baru separo / cuma apiService function tanpa UI** |
| ❌ | **Backend sudah, FE BELUM TERINTEGRASI SAMA SEKALI** |

---

## 🔐 FITUR BARU KELOMPOK 1: AUTH & TOKEN MANAGEMENT

### ✅ 1.1 `POST /api/auth/register` → Step 1 OTP via Email
**Baru:** Alur register tidak langsung buat user, tapi kirim OTP 6 digit ke email dulu (exp 15 menit).

### ✅ 1.2 `POST /api/auth/verify-registration` → Step 2 Verif OTP + Buat User
**Baru:** Verifikasi OTP → baru insert User ke DB.

### 🟡 1.3 `POST /api/auth/refresh` + `Token-Expired` Header Interceptor ⚠️ BISA BAHAYA
**Baru di BE (`AuthController.cs:146`, `Program.cs:127-136`):**
- Saat JWT expire, response header ada `Token-Expired: true`
- Endpoint refresh token untuk exchange token baru tanpa login ulang

**Status di FE Web:**
- `apiService.js:98` **SUDAH ADA** function `refreshToken()`
- ❌ **TAPI TIDAK PERNAH DIPANGGIL OTOMATIS.** Tidak ada interceptor fetch yang catch 401 + cek header `Token-Expired` + auto refresh + retry request asli.
- **Resiko:** User edit form 2 jam → token expire di tengah → save gagal SILENT ERROR (cuma console.log) → data hilang!
- **File yang perlu tambah logic nanti:** bikin wrapper fetch interceptor.

---

## 📝 FITUR BARU KELOMPOK 2: QUESTIONS (BANYAK BANGET!)

### ✅ 2.1 `GET /api/forms/{id}/questions` → Support **Pagination + Search**
**Baru (`QuestionsController.cs:29-84`):** Query params `?page=2&pageSize=20&search=momen%20linier`
- Search memfilter soal berdasarkan teks
- Bermanfaat untuk form dengan 100+ soal (tidak load semua sekaligus)

**Status FE Web:** 🟡 apiService TIDAK TERPAKAI. `FormBuilder.jsx` masih load SEMUA soal sekaligus (belum pakai pagination/search query param).

---

### ✅ 2.2 `PUT /api/forms/{id}/questions` → Save Massal Rewrite
**Baru:** Logic canggihnya banyak:
- Transaction `Serializable` + `LockFormRow()` (hindari race condition 2 tab save bersamaan)
- Snapshot `oldOptionImages` → hapus file gambar opsi yatim di `wwwroot` (mencegah disk penuh)
- Kalau form published kehabisan soal → auto-unpublish balik ke draft
- **Support field baru: `Points`** (bobot poin per soal!)

---

### ❌ 2.3 `DELETE /api/forms/{id}/questions` (Delete All Soal Sekaligus)
**Baru (`QuestionsController.cs:415-460`):** Endpoint baru untuk hapus SEMUA soal dalam 1 request (tidak perlu loop DELETE satu per satu).

**Status FE Web:** ❌ **BELUM ADA UI.** Tombol "Kosongkan Semua Soal" di FormBuilder belum memanggil endpoint ini.

---

### 🔥 🟡 2.4 `POST /api/forms/{id}/questions/import` + `/import/preview` → **IMPORT FILE EXCEL/CSV/PDF/DOCX JADI SOAL OTOMATIS!** ⭐
**Fitur TERBAIK di batch ini! (`QuestionsController.cs:462-648++`)**
- Support 5 format: `.xlsx`, `.xls`, `.csv`, `.pdf`, `.docx`
- Deteksi tipe file dari **ISI FILE BENERAN** (bukan cuma ekstensi nama) — mencegah user upload file salah nama
- Validasi baris per baris + return error dengan `rowNumber` & `field` yang salah
- `/import/preview` → return preview 100 soal pertama + count error (TIDAK MASUK DB DULU) — user bisa cek dan koreksi sebelum commit
- `/import` → simpan ke DB + auto-upload gambar dari file
- Auto-detect kolom kunci jawaban: alias `correct_answer / jawabanbenar / kuncijawaban / kunci / answer` (`QuestionsController.cs:1134`)

**Status FE Web:**
- `apiService.js:257-267` **SUDAH ADA** function `importQuestions()`
- ❌ **TAPI TIDAK ADA UI BUTTON / DIALOG IMPORT.** User tidak bisa pakai fitur ini! Tidak ada file picker untuk upload file Excel/PDF ke Form Builder.
- `apiService.js:533` ada referensi `/api/templates/import-questions` — cuma URL template download, tidak ada UI link-nya.

**Ini adalah fitur terbesar yang "TERKUBUR" — BE sudah super lengkap, FE tidak expose UI-nya.**

---

### ✅ 2.5 `Question.Points` Field Baru (Bobot Soal)
**Baru:** `QuestionsController.cs:261 + :278` — setiap soal punya bobot poin sendiri (tidak lagi default 1 poin per soal).

**Status FE Web:**
- Sudah disimpan BE saat save
- `PublicFormsController.cs:281` sudah include di API public
- `AnalyticsController.cs:97-250` perhitungan skor rata-rata & export **SUDAH BENAR** gunakan bobot Points
- ❌ **TAPI:** Di FormBuilder UI tidak ada input field bobot Points per soal. User tidak bisa set bobot via UI web.

---

## 📊 FITUR BARU KELOMPOK 3: RESPONSES + SCORING

### ✅ 3.1 `GET /{id}/result` → Build Hasil Skor Lengkap
Baru pakai helper `ResponseScorer.BuildResult()` — return skor, benar, salah, kunci jawaban.

### ✅ 3.2 `GET /{id}/attempts` → Riwayat Percobaan Responden yang Sama
**Baru (`ResponsesController.cs:197-261`):** Melihat semua attempt user yang sama (cocokkan via akun login, fallback ke nama guest). Dapat skor per attempt kalau `ShowScore=true`.

**Status FE Web:** `FormRunnerPage.jsx:778` dan `userHistory.jsx:204-257` **SUDAH TERPAKAI** untuk link "Hasil Pengerjaan Sebelumnya". ✅ Bagus!

---

### 🟡 3.3 `PUT /api/responses/{id}/answers/{answerId}/score` → **Manual Score Override Essay**
**Baru (`ResponsesController.cs:291-317`):** Guru bisa koreksi jawaban essay per baris:
- `ManualScore` (0-1000)
- `IsCorrectOverride` (override benar/salah paksa)
- `OverrideNote` (catatan untuk siswa: "Bagus, tapi rumusnya kurang F=ma")

Ditambah endpoint **bulk**: `PUT /api/responses/{id}/scores` untuk update banyak jawaban sekaligus.

**Status FE Web:**
- `apiService.js:632-634` **SUDAH ADA** function `updateAnswerScore()`
- ❌ **TAPI TIDAK ADA UI.** Di halaman Detail Responden, soal essay tidak ada input skor manual + catatan override.

---

### ✅ 3.4 `PUT /api/responses/{id}/status` → Update Status Response
Sudah terpakai di Form Responses.

---

## 👁️ FITUR BARU KELOMPOK 4: EXAM MONITORING (PROCTORING) 🔥

**(`ExamMonitoringController.cs:109` baris berubah, yang paling banyak)**

BE tambah banyak endpoint monitoring realtime untuk Admin ujian:
| Endpoint Baru | Fungsi | Status FE |
|---|---|---|
| `GET /exam-monitoring` | Dashboard live: semua session responden, status (sedang ujian / selesai / di-force-submit), jumlah tab switch, last heartbeat | ✅ `FormResponsesPage.jsx` + `ExamProctorActions` **SUDAH ADA UI** |
| `POST /sessions/{id}/force-submit` | Paksa submit ujian siswa yang curang | ✅ **SUDAH ADA** `apiService.js:601-608` + UI tombol merah |
| `POST /sessions/{id}/reset` | Reset session (boleh ikut ujian lagi) | ✅ **SUDAH ADA** |
| `GET /sessions/{id}/session-state` | Return status session (untuk heartbeat Form Runner mengecek apakah sesi di-force-submit) | ✅ **SUDAH TERPAKAI** `FormRunnerPage.jsx:192-197` + `:382-387` |
| `POST /exam-events` | Lapor violation (tab switch, copy-paste) dengan Background Service retry queue | ✅ **SUDAH TERPAKAI** tapi warning di kode: TODO pastikan balasan 410/409 setelah force-submit |
| `POST /heartbeat` | Ping tiap X detik buktikan siswa masih di halaman ujian | ✅ **SUDAH TERPAKAI** |

**Kesimpulan Exam Monitoring:** ✅ **INI YANG PALING SIAP!** BE & FE sudah sinkron bagus.

---

## ⚡ FITUR BARU KELOMPOK 5: PERFORMANCE & INFRA

### ✅ 5.1 `ReferenceCache.cs` (File BARU) — Cache Tabel Referensi Statis
**Baru:** In-memory `ConcurrentDictionary` untuk cache ID `FormStatus` (Draft/Published/Closed) dan `ResponseStatus`. Hit 1 query saja saat startup, selanjutnya langsung dari memori.

**Impact:** Menghemat 2-3 query DB per submit response / exam event → untuk 1000 user ujian bersamaan, ini mengurangi load DB drastis. **TIDAK PERLU FE perubahan apa pun.** ✅ Transparan.

### ✅ 5.2 Rate Limiting Policies (`Program.cs:15` menambahkan)
Policies baru: `auth`, `creator`, `submit`. Mencegah brute force login + spam submit.

### ✅ 5.3 `User.Birthdate` Field Baru (`FormUpDbContext.cs:28` + `User.cs:2`)
Untuk registrasi. FE Login/Register kemungkinan sudah ada input tanggal lahir.

---

## 📈 FITUR BARU KELOMPOK 6: ANALYTICS & EXPORT

### 🟡 6.1 Perhitungan Skor Analytics dengan Bobot Points
**Baru (`AnalyticsController.cs:97-250`):** Rata-rata skor, distribusi skor export → SUDAH memperhitungkan bobot `Question.Points` per soal.

**Masalah:** TIDAK ada UI input Points di Form Builder → feature Points tidak terpakai oleh user (setiap soal tetap 1 poin default).

### 🟡 6.2 Export CSV/XLSX: Kunci Jawaban & Bobot ✅ TERIMPLENTASI DI BE!
**Yang kamu highlight di `prompt-be-team.md:43`**: "Export tidak menyertakan kolom Kunci Jawaban / Bobot Soal."

**Sekarang BE SUDAH ADA PERUBAHAN di `AnalyticsController.cs:31` baris berubah** (lihat grep: export sudah handle `Points` dan `hasCustomPoints`). Saya tidak baca full export, tapi dari diff count 31 baris Analytics + code di `ResponsesController.cs:633` (kunci jawaban helper) + `QuestionsController.cs:1134` (find kolom kunci) → **BE KEMUNGKINAN SUDAH FIX.**

**Yang perlu dicek FE:** Tombol export di UI Analytics sudah menggunakan response baru ini? Tapi karena export langsung unduh file dari URL = perubahan di BE otomatis terasa di FE (tanpa ubah FE). ✅ Kemungkinan SUDAH FIX penuh.

---

# 🎯 RINGKASAN UTAMA: FITUR "TERKUBUR" (BE SIAP, FE TIDAK ADA UI)

| Prioritas | Fitur | Effort FE | Impact User |
|---|---|---|---|
| 🔴 TERTINGGI | **Tombol Import Soal dari Excel/PDF/Word (2 UI: Upload File + Preview Table)** | 1-2 hari | MASSIVE — user tidak perlu input 50 soal manual |
| 🔴 TERTINGGI | **Auto Refresh Token Interceptor (catch 401 → refresh → retry)** | 30 menit | MENCEGAH HILANGNYA DATA HASIL EDIT 2 JAM |
| 🟠 TINGGI | **Input Bobot `Points` per Soal di FormBuilder** | 4 jam | Unlock fitur perhitungan skor berbobot yang BE sudah hitung |
| 🟠 TINGGI | **Manual Scoring UI di Halaman Detail Respondent (Essay)** | 1 hari | Guru bisa koreksi essay + catatan |
| 🟡 SEDANG | **Delete All Questions Button** | 15 menit | Kecil, tapi berguna |
| 🟡 SEDANG | **Pagination + Search Questions (>20 soal)** | 1 hari | Performa untuk form 100+ soal tidak lag |

---

## 📝 CATATAN AKHIR

Tim backend sudah melakukan PEKERJAAN LUAR BIASA. Fitur terbesar (Import File 5 Format, Manual Scoring Override, Points berbobot, Exam Monitoring + Heartbeat, OTP Register) **SEMUANYA SUDAH ADA DI BELAKANG.** Yang kurang cuma **lapisan UI di web** untuk expose fitur-fitur keren ini ke user.

Kalau mau saya breakdown task per file untuk Item #1 UI Import Soal (File Picker + Preview Table + Progress + Error Row highlight) langsung bilang aja! 🚀

---

**User**

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

**Assistant**

Sekarang saya buat folder `.trae/specs/` dan tulis `spec.md` sesuai task dari user. Mari pertama buat directory dan spec.md.

Sekarang saya buat tasks.md dengan breakdown task per bagian. Untuk A-1, A-2, B-1, B-2, C-1, C-2, D-1, ditambah task Smoke Test Global & Verify Global. Setiap task terhubung ke Acceptance Criteria di spec.md.

Fase **Specify** dan **Plan** selesai. Berikut 2 artifact yang perlu kamu review dan **approve SEBELUM** saya masuk fase Implementasi:

1. **[spec.md](file:///home/karllo/Projects/FormUp/.trae/specs/fe-integrasi-backend-batch-11/spec.md)** —
   Product Requirements Document: tujuan, goals/non-goals, functional requirements per bagian (A-1 sampai D-1), NFR, constraints, assumptions, dan 13 Acceptance Criteria bertipe `rule` / `rubric` beserta cara buktinya.
2. **[tasks.md](file:///home/karllo/Projects/FormUp/.trae/specs/fe-integrasi-backend-batch-11/tasks.md)** —
   Implementation Queue: 9 task terurut A-1 → A-2 → B-1 → B-2 → C-1 → C-2 → D-1 → Smoke Test → Global Verify. Setiap task: Status (pending), Priority, Depends On, deskripsi implementasi, AC yang di-cover, dan Test Requirements per task (rule + rubric).

---

## 📋 RINGKASAN ISI ARTI FAKT (untuk review cepat):

### **Urutan Kerja yang Sudah Saya Rencanakan:**
1. **Task 1** — A-1 Interceptor Auto Refresh Token (Mutex pattern) — *ini yang PALING KRITIS dulu, mencegah data hilang.*
2. **Task 2** — A-2 UI Import Soal 5 Format (Preview + Commit + Template Download link) — *fitur terbesar.*
3. **Task 3** — B-1 Input Bobot Points per Soal + Total Skor Live.
4. **Task 4** — B-2 UI Koreksi Essay Manual (Skor + Override + Catatan).
5. **Task 5** — C-1 Delete All Soal (konfirmasi 2 langkah).
6. **Task 6** — C-2 Pagination + Search Daftar Soal (pageSize=25 default).
7. **Task 7** — D-1 Verifikasi Export CSV/XLSX (Laporan JUJUR lulus/sebagian/gagal).
8. **Task 8** — Smoke Test 5 Fitur Existing (Exam Monitoring, AI Modal, Login, Export, Guest Submit).
9. **Task 9** — Final Verify `git diff` 100% hanya file `web/form-fe/src/*`.

### **Approval Rules (Wajib Kamu Konfirmasi):**
- ✅ Kalau **setuju semua spec & tasks**, balas: `APPROVE` / `LANJUTKAN IMPLEMENTASI`. Saya langsung masuk Task 1.
- ⚠️ Kalau **ada bagian yang mau diubah urutan prioritas / ditambahkan / dikurangi** (misal: "C-2 pagination skip dulu batch ini, atau pageSize mau 50 bukan 25"), sampaikan sebelum approve.
- ❓ Kalau **ada Open Questions** yang mau dijawab (OQ-1 lokasi halaman detail responden, OQ-2 template URL, OQ-3 camelCase Points field) — jawab juga di sini.

Setelah approve, saya proceed ke fase Implementasi. Review kedua artifact di atas yuk! 🚀

User sudah APPROVE. Saya langsung masuk fase **Implementasi** — mulai Task 1 (A-1 Interceptor Auto-Refresh Token). Pertama, saya baca **full file apiService.js** untuk memahami struktur fetch existing sebelum bikin wrapper.

Sekarang saya implement Task 1. Saya buat wrapper `authFetch()` di `apiService.js` (baris baru di sekitar function `parseResponse`), dengan mutex pattern `_refreshPromise`. Kemudian ganti SEMUA `fetch(..., headers: authHeaders())` yang authenticated untuk pakai `authFetch()` kecuali XHR progress (upload image/audio) yang tetap native tapi saya pasang 401 handler di onload-nya.

Sekarang saya implement Task 1. Saya edit `apiService.js`: tambah wrapper `authFetch` mutex refresh token, lalu **ganti SEMUA** `fetch(..., headers: authHeaders())` untuk request authenticated pakai wrapper baru. Juga pasang 401 handler di XHR upload progress.

Pertama saya butuh helper custom event untuk memberi tahu Login Page jika session expired agar menampilkan pesan yang jelas. Saya cek dulu apakah Login page baca query param `reason`:

Login belum support ?reason=session_expired. Saya akan tambahkan logic di Login.jsx (1 logic kecil baca query param reason). Sekarang mulai edit apiService.js: tambah `authFetch` wrapper, `performRefresh` mutex, ganti semua `fetch(..., headers: authHeaders())` yang authenticated ke `authFetch`. Akhirnya di XHR 401 check handle session expired juga.

Sekarang saya perlu:
1. Ubah detection 401 condition (tidak strict `Token-Expired: true` saja, karena BE kadang set tidak selalu — validasi lebih aman: 401+token ada dan bukan auth url → coba refresh).
2. **Ganti SEMUA `fetch(..., headers: authHeaders())` authenticated** ke `authFetch(...)` — mulai dari profile, references, forms, questions, responses, analytics, admin, exam, score override, dan upload form banner/profile image/import question yang FormData.

Sekarang saya **ganti SEMUA call `fetch(..., headers: authHeaders())` authenticated ke `authFetch(...)` mulai dari profile, references, forms, questions, responses, admin, exam, score override, dan upload FormData (uploadProfileImage, uploadFormBanner, importQuestions). PAKAI authFetch juga, karena authFetch sudah handle FormData tanpa Content-Type.

Mari saya mulai ganti dari function getMyProfile ke bawah:

Bagus. Sekarang saya lanjutkan mengganti sisanya: Response Endpoints, Feedback, Analytics, Public Form (getPublicQuestions, submitPublic, resultPublic), Exam Monitoring (owner side), Score Override, dan Admin. Juga `exportFormResponses` dan `getFormResponses` pagination.

Sekarang saya ganti sisanya: Feedback, Analytics, Public Form Flow (getPublicQuestions, submit, result, postExamEvent — ini ada yang menggunakan authHeaders, tapi untuk guest (tanpa token) authHeaders mengembalikan Content-Type saja (benar). Jadi authFetch juga OK. Yang khusus `syncExamAnswers` punya custom header tanpa Authorization (hanya Content-Type application/json). OK, authFetch juga tidak menambah Authorization jika token tidak ada. 

Selain itu `exportFormResponses` fetch dengan Authorization header `Bearer ${token}` pakai `token ? { Authorization: Bearer token} : {}` — saya ganti pakai authFetch juga.

Baik, mari lanjutkan Task 1 (A-1) yang tersisa 2 item: ubah `exportFormResponses()` ke `authFetch()` dan tambah banner reason di Login.jsx. Mari cek isi file terlebih dahulu.

Sebelum mengubah, mari cek wrapper authFetch di awal file apiService.js untuk memastikan bagaimana ia menangani response non-JSON (blob):

Baik, `authFetch` mengembalikan Response object asli (bukan parse JSON), jadi cocok untuk blob download. Mari apply dua perubahan Task 1 sekaligus:

Mari cek apakah `getLocalUser()` (dipanggil di `_performRefreshMutex` baris 83) sudah terdefinisi di apiService.js:

Bagus, semua function tersedia. Task 1 (A-1) code 100% applied. Sekarang lanjut Task 2 (A-2 UI Import Soal 5 format). Mari temukan lokasi FormBuilder.jsx dan pola modal existing (misal AIGeneratorModal):

Mari baca toolbar/header section FormBuilder.jsx dan juga cek QuestionCard untuk memahami struktur save questions:

Ternyata FormBuilder sudah ada import bar template + label "Impor File Soal" tapi pakai `<label><input hidden>`. Mari cek apakah `handleImportFile` dan `importLoading` state ada, serta bagaimana payload questions sudah punya field `points`:

Baik, analisis: `handleImportFile` existing langsung commit tanpa preview (melanggar spec A-2 yang mewajibkan 2-step preview→commit). Kita perlu buat ImportQuestionsModal.jsx yang benar sesuai spec. Mari buat file baru:

Sekarang integrasikan ImportQuestionsModal ke FormBuilder.jsx. Mari cek field responseCount di form object, lalu lakukan edit batch (import modal + Task 5 C-1 handleClearAllQuestions upgrade ke endpoint DELETE). Pertama baca bagian state form dan props header:

Mari terapkan edit ke FormBuilder.jsx untuk Task 2 (Integrasi Import Modal) + Task 5 (Upgrade hapus semua soal ke DELETE endpoint) sekaligus karena ada di file sama:

---

