# FormUp Web Frontend (`form-fe`)

Frontend web FormUp: form builder, dashboard, dan form runner. Dibangun dengan **React 19 + Vite**, **Tailwind CSS v4**, `react-router-dom`, dan `lucide-react` — sepenuhnya JavaScript (JSX), tanpa TypeScript.

## Menjalankan

Prasyarat: Node.js LTS dan backend API yang berjalan di `http://localhost:5000` (lihat [`api/README.md`](../../api/README.md)).

```bash
npm install
npm run dev        # dev server di http://localhost:5173
```

Perintah lain:

```bash
npm run build      # build produksi ke dist/
npm run preview    # preview hasil build
npm run lint       # ESLint
```

## Struktur

```
src/
├── main.jsx                  # Entrypoint + router
├── App.jsx                   # Layout & route guard
├── components/
│   ├── layout/               # Sidebar, Topbar
│   └── ui/                   # Button, ConfirmModal, ProtectedRoute, editor, dst.
├── features/
│   ├── auth/                 # Login, Register, VerifyRegister, ForgotPassword
│   ├── admin/                # Dashboard admin
│   ├── dashboard/            # My forms, responses, templates, history
│   ├── form-builder/         # CreateForm, FormBuilder
│   ├── form-responses/       # Responses & analytics per form
│   ├── form-runner/          # Pengisian form publik
│   └── profile/              # Profil pengguna
├── services/apiService.js    # Client REST ke backend API
└── utils/                    # Helper render rich content
```

## Catatan

- CORS backend sudah mengizinkan `http://localhost:5173`.
- Tipe pertanyaan memakai ID reference table yang sama dengan mobile/API: 1 Essay, 2 Pilihan Ganda, 3 Checkbox, 4 Tanggal & Waktu, 5 Benar/Salah.
- Belum ada framework test yang dikonfigurasi.
