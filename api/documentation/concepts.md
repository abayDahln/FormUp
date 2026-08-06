# FormUp — API (ASP.NET Core) — Keamanan & Stabilitas

> Dokumen ini fokus ke konsep yang harus ada di sisi **backend/API**. API adalah satu-satunya pintu masuk ke database, jadi ini lapisan paling kritis — kalau API bocor atau tidak stabil, web dan mobile ikut kena imbasnya.

---

## 1. Autentikasi & Otorisasi

**Kenapa penting:** API melayani dua jenis klien (web browser dan mobile app) yang punya karakteristik berbeda, plus ada dua jenis "pengguna" — form creator yang login, dan respondent publik yang sering kali tidak login sama sekali.

**Konsep yang dibutuhkan:**
- **Access token berumur pendek** (hitungan menit) dan **refresh token berumur panjang** (hitungan hari/minggu) — supaya kalau access token bocor, dampaknya terbatas waktu.
- **Cara penyimpanan refresh token harus dibedakan berdasarkan jenis klien**: browser mendukung cookie yang tidak bisa diakses JavaScript (lebih aman dari pencurian via script), sedangkan mobile app tidak punya mekanisme itu sehingga token dikirim di response body dan disimpan di secure storage milik OS.
- **Refresh token harus bisa dicabut (revoke)** — misalnya saat user logout dari satu device, atau saat terdeteksi aktivitas mencurigakan. Ini butuh refresh token disimpan (dalam bentuk hash) di database, bukan cuma divalidasi lewat signature saja.
- **Role-based authorization** — pembedaan hak akses form creator vs admin, supaya endpoint sensitif (misal hapus akun user lain) hanya bisa diakses role yang tepat.
- **Endpoint publik untuk respondent** (mengisi & submit form) sengaja **tidak butuh login** — tapi tetap butuh proteksi lain (dibahas di bagian Perlindungan Form Publik).

---

## 2. Validasi Input (Lapisan Wajib, Tidak Bisa Diskip)

**Kenapa penting:** Validasi di frontend itu untuk kenyamanan pengguna (feedback instan), tapi **tidak bisa dipercaya** sebagai satu-satunya penjaga — siapa pun bisa memanggil API langsung tanpa lewat aplikasi web/mobile (misalnya lewat Postman atau script).

**Konsep yang dibutuhkan:**
- Setiap data yang masuk dari luar (body request, query parameter, file upload) harus divalidasi ulang di backend, terlepas dari apa yang sudah divalidasi di sisi client.
- Validasi mencakup: panjang teks maksimal, format yang diharapkan, tipe data yang sesuai, dan aturan bisnis (misalnya: pertanyaan tipe pilihan ganda wajib punya minimal dua opsi).
- Pesan error validasi harus jelas dan terstruktur, supaya frontend bisa menampilkan pesan yang tepat ke pengguna tanpa harus menebak-nebak dari teks error mentah.

---

## 3. Rate Limiting Bertingkat

**Kenapa penting:** FormUp punya karakteristik unik — form-nya publik, artinya satu form bisa diakses ratusan/ribuan orang sekaligus (misalnya kuis yang dibagikan ke satu kelas). Kalau rate limiting dipukul rata untuk semua endpoint, ini bisa membuat pengguna legitimate ikut terblokir, atau sebaliknya, endpoint sensitif jadi rentan diserang.

**Konsep yang dibutuhkan:**
- **Endpoint login/register** perlu batasan paling ketat, karena ini target utama serangan brute force.
- **Endpoint manajemen form** (dipakai form creator yang sudah login) perlu batasan sedang — cukup untuk mencegah penyalahgunaan tanpa mengganggu alur kerja normal.
- **Endpoint submit form publik** perlu batasan yang lebih longgar dan **berbasis kombinasi identitas** (bukan cuma alamat IP), karena banyak respondent bisa berasal dari jaringan yang sama (sekolah, kantor, WiFi publik). Kalau cuma dibatasi per-IP, orang-orang di jaringan yang sama akan saling memblokir satu sama lain.

---

## 4. Perlindungan Form Publik (Anti-Spam & Anti-Duplikasi)

**Kenapa penting:** Ini konsep yang **unik untuk FormUp** dibanding aplikasi web/mobile pada umumnya, karena sifat form-nya publik dan bisa diisi tanpa login.

**Konsep yang dibutuhkan:**
- **Deteksi submission ganda** — untuk form yang settingnya "satu respons per orang". User login dilacak via `respondent_id`; **guest dilacak via `guest_token`** yang dikirim klien (client harus menyimpan token yang sama, mis. localStorage). Keduanya ditolak `400` jika sudah pernah submit.
- **Perlindungan dari bot otomatis** — **belum dibuat** (ditunda — lihat `future_features.md`). Ide: field tersembunyi yang hanya terisi oleh bot, atau verifikasi tanpa interaksi eksplisit.
- **Validasi bahwa form masih aktif** — form yang sudah ditutup, di-takedown, atau melewati `close_form_time` / belum melewati `open_form_time` menolak submission. **Pesan dibedakan**: `404 Form tidak ditemukan` (tidak ada/takedown/bukan published), `403 Form belum dibuka` (belum `open_form_time`), `403 Form sudah ditutup` (lewat `close_form_time` / status closed).
- **Perlindungan penebakan link form** — untuk form yang **tidak ditemukan**, pesan tetap generik (`404 Form tidak ditemukan`) supaya tidak membantu menebak link privat. Catatan: status `403 belum dibuka/ditutup` memang mengungkap bahwa form itu ada — ini sengaja diminta agar responden tahu kapan form bisa dikerjakan.

---

## 5. Mencegah Duplikasi Data akibat Retry Otomatis

**Kenapa penting:** Baik web maupun mobile mungkin melakukan retry otomatis saat request gagal karena koneksi tidak stabil. Kalau submission form ikut di-retry tanpa mekanisme pengaman, satu jawaban bisa tersimpan dua kali di database — padahal request pertama sebenarnya sudah berhasil, cuma responsnya yang tidak sampai ke client karena koneksi putus di tengah jalan.

**Status: ditunda** — mekanisme idempotency-key belum dibuat (lihat `future_features.md`). Untuk MVP, double-submit akibat retry bisa dicegah sebagian lewat rate limiting per form+IP dan `one_response`.

**Konsep yang dibutuhkan (saat implementasi nanti):**
- Setiap aksi yang **mengubah data** (bukan sekadar membaca) dan berpotensi di-retry harus punya cara untuk mengenali "ini request yang sama yang dicoba lagi" versus "ini request baru yang berbeda". Dengan begitu, kalau ada percobaan kedua dari request yang identik, backend cukup mengembalikan hasil yang sudah ada sebelumnya, bukan memproses ulang dari nol.
- Ini penting khususnya untuk submit response form, karena datanya tidak bisa dengan mudah "dibersihkan" duplikatnya secara manual setelah masuk database dalam jumlah besar.

---

## 6. Keamanan Unggah File

**Kenapa penting:** FormUp punya beberapa fitur yang melibatkan file — gambar banner form, gambar pada pertanyaan, upload jawaban dari respondent, dan import pertanyaan lewat CSV/Excel. File upload adalah salah satu vektor serangan paling umum kalau tidak ditangani dengan hati-hati.

**Konsep yang dibutuhkan:**
- **Verifikasi jenis file berdasarkan isi file yang sebenarnya**, bukan cuma nama ekstensinya — karena nama file gampang dipalsukan (file berbahaya bisa diberi nama `gambar.jpg` padahal isinya bukan gambar).
- **Batasan ukuran file** yang wajar sesuai kebutuhan (gambar tidak perlu sebesar file CSV data).
- **Nama file yang disimpan di server harus di-generate ulang**, bukan memakai nama asli dari pengguna — untuk mencegah percobaan menembus struktur folder server lewat nama file yang aneh.
- **File yang diunggah publik (lewat form) perlu perlakuan lebih hati-hati** dibanding file yang diunggah form creator yang sudah terverifikasi, karena siapa pun bisa mengunggahnya.

---

## 7. Format Respons yang Konsisten

**Kenapa penting:** API ini dipakai oleh dua aplikasi klien berbeda (web dan mobile) yang dikembangkan terpisah. Kalau format respons tidak konsisten antar endpoint, setiap sisi klien harus menulis logic penanganan yang berbeda-beda untuk tiap endpoint — ini menambah kompleksitas dan potensi bug.

**Konsep yang dibutuhkan:**
- Semua endpoint sebaiknya mengembalikan struktur dasar yang sama untuk kasus sukses, kasus gagal (error), dan kasus data berhalaman (pagination) — sehingga web dan mobile bisa memakai satu logic pemrosesan respons yang seragam, bukan menulis parsing khusus per endpoint.
- Penanganan error sebaiknya dipusatkan di satu tempat (bukan ditulis berulang di tiap endpoint), supaya semua error — baik yang terduga (validasi gagal) maupun tidak terduga (bug/exception) — tetap dikembalikan dalam format yang bisa diprediksi oleh klien.

**Konten rich text (Delta JSON):** kolom `question` dan `description` bisa berisi plain text atau **Delta JSON** (format Quill) untuk teks berformat (bold, italic, warna font, ukuran font, alignment, list, dsb).
- API mendeteksi format dari isi lalu menyimpannya di kolom `question_format` / `description_format` (`delta` atau `text`).
- Setiap respons yang membawa `question` / `description` juga menyertakan `questionFormat` / `descriptionFormat` agar klien tahu cara merender. Untuk data lama (belum ada kolom format), API mendeteksi dari isi konten.
- Validasi server: konten yang diawali `[` wajib berupa Delta JSON yang valid, jika tidak API menolak dengan `400` — mencegah data rusak masuk DB.

---

## 8. Proteksi CORS

**Kenapa penting:** CORS adalah aturan yang dijalankan browser untuk mencegah situs web sembarangan memanggil API milikmu dari luar domain yang diizinkan. Ini **hanya relevan untuk web**, tidak berlaku untuk mobile app.

**Konsep yang dibutuhkan:**
- Daftar domain yang diizinkan harus eksplisit disebutkan satu per satu (domain development dan domain production berbeda), bukan mengizinkan semua domain secara serampangan.
- Kalau API memakai cookie untuk autentikasi web, aturan CORS harus dikonfigurasi agar cookie ikut terkirim — tapi ini punya konsekuensi: domain yang diizinkan **tidak boleh** memakai aturan "izinkan semua", harus benar-benar spesifik disebut satu-satu.

---

## 9. Performa & Ketahanan (Resilience)

**Kenapa penting:** API yang lambat atau gampang crash saat traffic naik akan membuat pengalaman pengguna buruk, terutama saat form sedang ramai diisi banyak orang bersamaan.

**Konsep yang dibutuhkan:**
- **Query yang mahal (butuh waktu lama) sebaiknya bisa dibatalkan** kalau client sudah tidak butuh hasilnya lagi (misalnya pengguna berpindah halaman sebelum data selesai dimuat) — supaya server tidak buang-buang resource memproses sesuatu yang hasilnya tidak akan dipakai.
- **Cache hanya untuk data yang aman dibagikan ke banyak orang** (misalnya metadata form publik yang jarang berubah) — data yang sifatnya personal atau berubah cepat (misalnya daftar respons) tidak boleh ikut ter-cache, karena bisa menyebabkan satu pengguna melihat data milik pengguna lain.
- **Proses berat sebaiknya dikerjakan di latar belakang (background job)**, bukan diproses langsung dalam satu request-response — contohnya import ratusan pertanyaan dari CSV. Kalau diproses langsung, request akan timeout kalau datanya banyak, dan pengguna tidak bisa melakukan hal lain sambil menunggu.
- **Pemanggilan ke layanan eksternal** (kalau ada, misalnya layanan pengiriman email) sebaiknya punya mekanisme percobaan ulang otomatis yang wajar, plus mekanisme untuk "berhenti mencoba sementara" kalau layanan eksternal tersebut memang sedang bermasalah — supaya tidak terus-menerus membebani sistem yang sedang down.

---

## 10. Pencatatan Aktivitas (Audit) — Bertahap

**Kenapa penting:** Untuk investigasi kalau terjadi masalah (data hilang, akun disalahgunakan) dan untuk kepatuhan terhadap ekspektasi privasi pengguna.

**Konsep yang dibutuhkan (bisa ditunda ke fase lanjut):**
- Aktivitas sensitif seperti login, penghapusan form, atau ekspor data respons sebaiknya tercatat siapa yang melakukan dan kapan — ini beda dengan "logging teknis" biasa (yang mencatat error/debug), ini lebih ke jejak audit untuk keperluan investigasi manual.
- Logging infrastruktur yang lebih lengkap (pencatatan terstruktur untuk debugging produksi) memang belum krusial di tahap awal pembuatan, tapi audit trail dasar untuk aksi-aksi sensitif tetap baik untuk mulai dipikirkan sejak awal karena lebih sulit ditambahkan belakangan setelah data sudah banyak.

---

## Ringkasan Prioritas

### Wajib ada sebelum fitur inti berjalan
- Autentikasi dengan access & refresh token yang perlakuannya dibedakan sesuai jenis klien
- Validasi input di backend untuk semua endpoint
- Rate limiting minimal untuk endpoint login dan submit form publik
- Verifikasi file upload berdasarkan isi file, bukan nama
- Format respons API yang konsisten

### Penting, menyusul segera setelah fitur inti berjalan
- Mekanisme cegah duplikasi data akibat retry
- Perlindungan form publik dari bot & submission ganda
- Konfigurasi CORS yang benar dan spesifik
- Background job untuk proses berat (seperti import CSV)

### Bisa menyusul di fase lanjut
- Audit trail lengkap untuk semua aksi sensitif
- Circuit breaker untuk layanan eksternal
- Cache invalidation yang lebih canggih