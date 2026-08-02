# FormUp — Mobile (Flutter) — Keamanan & Stabilitas

> Dokumen ini fokus ke konsep yang harus ada di sisi **mobile app**. Mobile punya karakteristik berbeda dari web: bukan berjalan di browser, tapi punya aksesnya sendiri ke penyimpanan aman milik sistem operasi, dan punya masalah khas seperti koneksi terputus-putus saat berpindah tempat, serta siklus hidup aplikasi (dibuka, di-minimize, ditutup paksa) yang perlu ditangani.

---

## 1. Penyimpanan Token & Sesi Login

**Kenapa penting:** Berbeda dengan browser, mobile app tidak punya mekanisme cookie otomatis. Tapi mobile app punya keuntungan lain: sistem operasi (Android/iOS) menyediakan penyimpanan terenkripsi khusus yang lebih aman dibanding penyimpanan biasa.

**Konsep yang dibutuhkan:**
- **Token yang berumur pendek** (dipakai tiap request) cukup disimpan di memory aplikasi (state management), sama seperti prinsip di web — supaya kalau aplikasi di-uninstall atau data aplikasi dihapus, token pendek ini otomatis hilang.
- **Token yang berumur panjang** (untuk menjaga pengguna tetap login tanpa perlu memasukkan password berulang) harus disimpan lewat mekanisme penyimpanan aman bawaan sistem operasi — ini terenkripsi oleh OS dan terisolasi dari aplikasi lain, jauh lebih aman dibanding penyimpanan biasa yang bisa dibaca aplikasi lain di perangkat yang sama (pada perangkat yang sudah di-root/jailbreak).
- **Logout harus benar-benar membersihkan** semua data sesi yang tersimpan di penyimpanan aman, tidak cukup hanya menghapus dari memory — supaya kalau perangkat dipakai bergantian, sesi pengguna sebelumnya benar-benar hilang.

---

## 2. Identitas Klien di Setiap Permintaan

**Kenapa penting:** Karena backend yang sama dipakai oleh web dan mobile, backend perlu tahu permintaan datang dari klien jenis apa untuk memperlakukan token dengan cara yang sesuai (dijelaskan di dokumen API).

**Konsep yang dibutuhkan:**
- Setiap permintaan dari mobile app sebaiknya membawa penanda bahwa dia berasal dari mobile, bukan web — supaya backend tahu harus mengirim token lewat body response, bukan lewat cookie (yang memang tidak akan berfungsi untuk mobile).

---

## 3. Penanganan Koneksi Tidak Stabil

**Kenapa penting:** Ini tantangan paling khas di mobile dibanding web — pengguna mobile app sering berpindah tempat (dari WiFi ke data seluler, masuk gedung dengan sinyal lemah, dsb), jadi aplikasi harus tahan terhadap koneksi yang naik-turun.

**Konsep yang dibutuhkan:**
- Kegagalan request akibat jaringan sebaiknya dicoba ulang otomatis dengan jeda yang semakin lama tiap percobaan (bukan langsung dicoba ulang beruntun tanpa jeda, yang justru memperparah kondisi jaringan yang memang sedang buruk).
- Sama seperti di web, percobaan ulang otomatis ini **hanya aman untuk aksi yang sekadar membaca data** — untuk aksi yang mengubah data (submit jawaban form) butuh mekanisme tambahan supaya tidak tersimpan dua kali (lihat konsep idempotency di dokumen API).
- Aplikasi sebaiknya bisa mendeteksi kalau perangkat benar-benar tidak ada koneksi sama sekali (bukan cuma request gagal), dan menampilkan kondisi ini secara jelas ke pengguna, bukan menampilkan error yang membingungkan.

---

## 4. Penyimpanan Data Sementara/Offline

**Kenapa penting:** Mobile app hidup di lingkungan yang lebih sering online-offline dibanding aplikasi web biasa. Untuk FormUp, ini penting khususnya untuk kasus **mengisi form yang panjang** di lokasi dengan sinyal buruk.

**Konsep yang dibutuhkan:**
- Progres pengisian form yang panjang sebaiknya disimpan di penyimpanan lokal perangkat secara berkala, supaya kalau aplikasi tertutup paksa (baterai habis, di-swipe dari recent apps, dll) atau koneksi terputus lama, jawaban yang sudah diisi tidak hilang begitu saja saat aplikasi dibuka kembali.
- Data yang sering diakses tapi jarang berubah (misalnya daftar form milik pengguna, template) bisa disimpan sementara di perangkat, supaya aplikasi tetap bisa menampilkan sesuatu yang berguna bahkan saat koneksi sedang buruk, alih-alih menampilkan layar kosong.
- Perlu strategi yang jelas kapan data lokal ini dianggap kedaluwarsa dan perlu disinkronkan ulang dengan server, supaya pengguna tidak melihat data yang sudah lama tidak update tanpa disadari.

---

## 5. Manajemen Siklus Hidup Aplikasi

**Kenapa penting:** Aplikasi mobile bisa di-minimize, ditutup paksa oleh sistem karena kekurangan memori, atau dibuka kembali setelah lama tidak dipakai — ini beda dengan web yang biasanya "hidup" selama tab browser terbuka.

**Konsep yang dibutuhkan:**
- Saat aplikasi dibuka kembali setelah sekian lama, perlu ada pengecekan apakah sesi login masih valid, dan kalau token sudah kedaluwarsa, aplikasi harus otomatis mencoba memperbarui token sebelum menampilkan konten, bukan langsung menampilkan error atau memaksa login ulang tanpa alasan jelas.
- Kalau ada proses yang sedang berjalan (misalnya sedang mengunggah file/gambar) saat aplikasi di-minimize, perlu dipikirkan apakah proses tersebut boleh lanjut di latar belakang atau harus dijeda dan dilanjutkan saat aplikasi dibuka kembali.

---

## 6. Izin Akses Perangkat (Permissions)

**Kenapa penting:** FormUp di mobile kemungkinan butuh beberapa akses ke fitur perangkat — misalnya kamera untuk memindai QR code form, atau akses penyimpanan untuk memilih file gambar/CSV saat membuat pertanyaan atau mengimpor soal.

**Konsep yang dibutuhkan:**
- Setiap permintaan izin akses perangkat sebaiknya diminta **pada saat dibutuhkan** (misalnya izin kamera diminta saat pengguna menekan tombol "scan QR", bukan diminta semua sekaligus saat pertama buka aplikasi) — ini praktik yang lebih ramah pengguna dan sesuai pedoman platform modern.
- Aplikasi harus menangani dengan baik kondisi saat pengguna **menolak** izin yang diminta — fitur yang butuh izin tersebut sebaiknya menampilkan penjelasan yang jelas kenapa izin dibutuhkan, bukan diam-diam gagal atau crash.

---

## 7. Keamanan Saat Aplikasi Berjalan di Perangkat yang Dimodifikasi

**Kenapa penting:** Perangkat yang di-root (Android) atau di-jailbreak (iOS) punya risiko keamanan lebih tinggi — aplikasi lain di perangkat tersebut berpotensi bisa mengakses data yang seharusnya terisolasi.

**Konsep yang dibutuhkan (tingkat kepentingannya tergantung sensitivitas data FormUp):**
- Untuk aplikasi seperti FormUp yang tidak menyimpan data finansial langsung, deteksi root/jailbreak biasanya belum jadi prioritas tinggi di awal — tapi baik untuk mulai dipikirkan terutama kalau nanti ada fitur yang melibatkan data lebih sensitif (misalnya form yang mengumpulkan data pribadi/kesehatan).
- Yang lebih mendesak: memastikan komunikasi antara aplikasi dan server selalu terenkripsi (lewat koneksi aman), supaya data tidak bisa disadap saat lewat jaringan, terlepas dari kondisi perangkat penggunanya.

---

## 8. Pembaruan Aplikasi & Kompatibilitas Versi

**Kenapa penting:** Berbeda dengan web (yang otomatis selalu memakai versi terbaru begitu pengguna membuka halaman), aplikasi mobile yang sudah terpasang di perangkat pengguna **tidak otomatis update** kecuali mereka memperbarui lewat app store. Ini artinya bisa ada banyak versi aplikasi yang berjalan bersamaan di dunia nyata.

**Konsep yang dibutuhkan:**
- Backend yang berubah strukturnya (misalnya field baru yang wajib, atau field lama yang dihapus) berpotensi membuat aplikasi versi lama gagal berfungsi dengan baik, bahkan crash. Perlu dipastikan setiap perubahan yang berpotensi merusak kompatibilitas mundur dipikirkan dampaknya ke pengguna yang belum update aplikasinya.
- Untuk perubahan yang benar-benar besar dan tidak bisa dihindari, aplikasi sebaiknya bisa mendeteksi kalau versinya sudah terlalu usang untuk berkomunikasi dengan backend, dan memberi tahu pengguna untuk memperbarui aplikasi, alih-alih menampilkan error yang membingungkan.

---

## 9. Notifikasi & Update Real-Time (Fase Lanjut)

**Kenapa penting:** Salah satu fitur yang direncanakan FormUp adalah pemberitahuan saat ada respons baru masuk ke form. Ini bisa dirasakan langsung di mobile lewat notifikasi.

**Konsep yang dibutuhkan (belum prioritas di awal):**
- Ini butuh infrastruktur tambahan yang cukup kompleks (koneksi yang tetap terjaga antara aplikasi dan server, atau lewat layanan notifikasi push dari platform seperti Firebase). Baik dipikirkan strukturnya dari awal, tapi implementasi penuhnya wajar untuk ditunda sampai fitur inti (pembuatan form, pengisian, pengumpulan respons) sudah stabil terlebih dahulu.

---

## Ringkasan Prioritas

### Wajib ada sebelum fitur inti berjalan
- Penyimpanan token panjang lewat penyimpanan aman bawaan OS, bukan penyimpanan biasa
- Penanda jenis klien di setiap permintaan ke backend
- Penanganan dasar untuk koneksi terputus (deteksi offline, pesan jelas ke pengguna)
- Permintaan izin akses perangkat yang kontekstual dan sopan

### Penting, menyusul segera setelah fitur inti berjalan
- Penyimpanan progres form panjang secara lokal (auto-save)
- Retry otomatis yang aman (dengan jeda bertahap, dan hanya untuk aksi yang aman diulang)
- Penanganan siklus hidup aplikasi (refresh sesi saat dibuka kembali setelah lama)
- Strategi deteksi versi aplikasi usang

### Bisa menyusul di fase lanjut
- Notifikasi push untuk respons baru
- Deteksi perangkat yang dimodifikasi (root/jailbreak)
- Optimasi lanjutan untuk penyimpanan offline yang lebih kompleks