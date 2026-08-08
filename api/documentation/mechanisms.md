# Mechanisms — Ringan Client & Server

Daftar konsep/mekanisme yang sudah diterapkan untuk meringankan beban client (web & mobile) dan server, agar mudah dipahami dan digunakan kembali di semua platform.

## 1. Rate Limiting (Server)

| Mekanisme | Penjelasan |
|---|---|
| **Rate limit auth** | Maksimal 10 permintaan/menit per IP untuk endpoint login/register/OTP/refresh — mencegah brute-force akun. |
| **Rate limit creator** | Maksimal 120 permintaan/menit per user untuk pengelolaan form, soal, dan upload — mencegah penyalahgunaan API pembuat form. |
| **Rate limit submit** | Maksimal 60 permintaan/menit per kombinasi IP+form untuk endpoint publik (ambil soal, submit, hasil) — mencegah spam/DoS pada satu form. |

## 2. Pagination (Server + Client)

| Mekanisme | Penjelasan |
|---|---|
| **Paginasi daftar respons** | Endpoint `GET /forms/{id}/responses` menerima param `page` & `pageSize`; tanpa param tetap mengembalikan semua (backward-compatible), dengan param mengembalikan `{items, total, page, pageSize}`. |
| **Paginasi analytics** | Endpoint `GET /forms/{id}/analytics` menerima param `page` & `pageSize`; skor/rata-rata tetap dihitung dari seluruh data, tapi hanya responden pada halaman yang dikirim — ringan untuk client. |
| **Infinite scroll** | Screen respons & analytics memuat 20 item/halaman lalu menambah saat user mendekati ujung list, mengurangi payload & memori. |

## 3. Keamanan (Server)

| Mekanisme | Penjelasan |
|---|---|
| **Validasi isRequired server** | Soal wajib diverifikasi di server (bukan hanya client), sehingga payload kosong untuk soal wajib ditolak. |
| **Validasi kepemilikan opsi** | `optionId` harus milik soal yang dijawab dan tipe jawaban tidak boleh ditukar (mis. essay diisi option) — mencegah data korup. |
| **JWT key anti-default** | Server gagal start jika `JWT_KEY` memakai nilai default/placeholder atau < 32 karakter — mencegah pemalsuan token. |
| **Refresh terbatas** | Token yang kedaluwarsa hanya bisa di-refresh dalam jendela ±30 menit, bukan tanpa batas — membatasi masa pakai token curian. |
| **Error generik** | Exception mentah tidak pernah dikirim ke user; detail hanya dicatat di log server. |
| **One-response untuk user login** | Batasan "satu respons per orang" hanya dipaksakan untuk user login (via `RespondentId`), karena tamu tanpa akun tidak bisa diidentifikasi andal. |
| **Kunci jawaban tersembunyi** | Endpoint publik tidak pernah mengirim `isCorrect`/`correctAnswer` — responden tidak bisa menebak jawaban dari API. |

## 4. Performa Client

| Mekanisme | Penjelasan |
|---|---|
| **Countdown timer terisolasi** | Timer pengerjaan dipindah ke komponen kecil ber-state sendiri, sehingga setState tiap detik hanya me-rebuild badge, bukan seluruh layar runner. |
| **Tab lazy (IndexedStack)** | Navigasi bawah memakai IndexedStack lazy: tab yang belum dibuka tidak di-build, tab yang sudah dibuka state-nya dipertahankan — pindah tab tidak memicu fetch ulang. |
| **Cache gambar** | `Image.network` diberi `cacheWidth` (banner 800px, avatar 300px) agar di-decode lebih kecil — hemat RAM & bandwidth. |
| **Fetch paralel** | Data dashboard (stats + form + respons) diambil bersamaan, bukan berurutan — mempersingkat waktu tunggu. |

## 5. Resiliensi Client

| Mekanisme | Penjelasan |
|---|---|
| **Timeout + retry** | Setiap request HTTP memakai timeout 6 detik dan retry 1x dengan jeda bertahap saat koneksi tidak stabil — menghindari layar "hang" lama & mengurangi request ganda. |
| **Auto-refresh token** | Saat API balas 401 `token-expired`, client otomatis memanggil `/auth/refresh` lalu mengulang request tanpa login ulang — sesi tetap jalan tanpa intervensi user. |
| **Debounce refresh** | Pull-to-refresh daftar form dibatasi minimal 2 detik antar panggilan — mencegah spam request saat user menarik layar berulang kali. |
