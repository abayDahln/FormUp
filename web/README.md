# FormUp Web

> **Smart Form Builder for Forms, Quizzes & Assessments**

**FormUp** adalah platform **form builder berbasis web** yang membantu pengguna membuat form, kuis, ujian, dan assessment dengan lebih mudah dan fleksibel.

FormUp dilengkapi berbagai fitur seperti **timer, shuffle soal & jawaban, Word to Form, custom short link, dashboard statistik, hingga export hasil ke Excel.**

Aplikasi web ini berada di subfolder [`form-fe/`](./form-fe) dalam monorepo FormUp.

---

## Features

- **Timer & Auto Submit**
  Form otomatis disubmit ketika waktu pengerjaan habis.

- **Shuffle Questions & Answers**
  Acak urutan soal dan pilihan jawaban.

- **Word to Form**
  Buat form dari dokumen Word menggunakan template yang telah disediakan.

- **Custom Short Link**
  Buat link form yang lebih pendek dan mudah dibagikan.

- **Image Zoom**
  Tampilkan gambar dengan jelas dan dapat diperbesar.

- **Math Formula & Code**
  Mendukung tampilan rumus matematika dan code snippet pada soal.

- **Dashboard Statistics**
  Lihat statistik dan visualisasi hasil jawaban melalui dashboard.

- **Import & Export**
  Import soal dari **Word / Excel** dan export hasil jawaban ke **Excel**.

- **Multiple Question Types**
  Mendukung essay, pilihan ganda, checkbox, tanggal & waktu, dan benar/salah.

- **Custom Authentication**
  Sistem login & register menggunakan akun FormUp sendiri tanpa Google Login.

- **Dark & Light Mode**
  Pilih tampilan sesuai preferensi pengguna.

---

## Tech Stack

- **React 19** + **Vite**
- **JavaScript (JSX)** — tanpa TypeScript
- **Tailwind CSS v4**, `react-router-dom`, `lucide-react`

---

## Getting Started

Prasyarat: [Node.js](https://nodejs.org) LTS terbaru dan backend FormUp API yang berjalan di `http://localhost:5000` (lihat [`api/README.md`](../api/README.md)).

Dari root monorepo:

```bash
cd web/form-fe
npm install
npm run dev        # development server di http://localhost:5173
```

Perintah lain:

```bash
npm run build      # build produksi
npm run preview    # preview hasil build
npm run lint       # ESLint
```

---

## Use Cases

FormUp dapat digunakan untuk:

- Ujian dan kuis
- Assessment sekolah
- Pembuatan soal
- Training & evaluation
- Technical / Coding Test
- Survey & data collection

---

## Roadmap

- [x] Form Builder
- [x] Timer & Auto Submit
- [x] Shuffle Questions & Answers
- [x] Word to Form
- [x] Excel Import & Export
- [x] Dashboard Statistics
- [x] Custom Short Link
- [x] Math Formula & Code
- [x] Image Zoom
- [x] Custom Authentication
- [x] Dark / Light Mode

---

## Support

<div align="center">

### FormUp

**Build Forms. Collect Answers. Analyze Results.**

</div>
