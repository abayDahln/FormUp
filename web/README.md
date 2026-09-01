# 🌐 FormUp Web

> **Smart Form & Quiz Builder for Assessments, Surveys, and Education**

**FormUp** adalah platform form builder berbasis web yang membantu pengguna membuat form, kuis, ujian online, dan assessment interaktif dengan cepat, fleksibel, dan terintegrasi.

Aplikasi web berada di subfolder [`form-fe/`](./form-fe) dalam monorepo FormUp.

---

## 🚀 Fitur Unggulan

- 🎨 **Cinematic Landing Page**: Desain modern dengan siluet 3D smartphone interaktif, smooth inertial scroll, dan storytelling flow.
- ⏱️ **Timer & Auto Submit**: Batas waktu pengerjaan ujian/kuis dengan otomatis submit saat waktu habis.
- 🔀 **Shuffle Soal & Jawaban**: Pengacakan urutan nomor soal dan opsi pilihan ganda untuk mencegah kecurangan.
- 📄 **Word & Excel to Form**: Import soal massal dari dokumen Word (.docx) atau spreadsheet Excel (.xlsx / .csv).
- 🏆 **Kuis & Penilaian Poin**: Konfigurasi kunci jawaban, bobot poin per nomor, dan pembahasan instan.
- 🔗 **Custom Short Link & QR Code**: Bagikan form dengan link kustom pendek atau kode QR siap cetak.
- 📊 **Dashboard Analitik & Ekspor Excel**: Rekapitulasi visual skor responden dan ekspor data hasil ke spreadsheet.
- 🛡️ **Panel Kontrol Admin**: Moderasi pengguna, formulir publik, dan penanganan laporan umpan balik.
- 🌓 **Dark & Light Mode**: Tampilan responsif yang nyaman untuk semua kondisi pencahayaan.

---

## 🛠️ Tech Stack

- **React 19** + **Vite**
- **JavaScript (JSX)**
- **Tailwind CSS v4**
- **React Router v7**
- **Lucide React Icons**
- **GSAP & Lenis** (Scroll animation & smooth scrolling)

---

## 🏁 Memulai (Getting Started)

### Prasyarat
- [Node.js](https://nodejs.org/) LTS (v18.x / v20.x+)
- Backend FormUp API yang berjalan di `http://localhost:5000` (lihat [`api/README.md`](../api/README.md))

### Instalasi & Menjalankan

```bash
# 1. Masuk ke direktori web frontend
cd web/form-fe

# 2. Install dependensi
npm install

# 3. Buat file konfigurasi .env
cp .env.example .env

# 4. Jalankan development server
npm run dev
```

Buka browser di **`http://localhost:5173`**.

### Perintah Lainnya

```bash
npm run build      # Build aplikasi untuk rilis produksi (output ke dist/)
npm run preview    # Preview lokal hasil build produksi
npm run lint       # Cek kualitas kode dengan ESLint
```

---

## 📖 Dokumentasi Lengkap

Untuk panduan teknis mendalam mengenai struktur folder, routing, integrasi API, tipe soal, dan troubleshooting, silakan baca:
👉 **[`web/form-fe/README.md`](./form-fe/README.md)**

---

<div align="center">

### FormUp Web
**Build Forms. Collect Answers. Analyze Results.**

</div>
