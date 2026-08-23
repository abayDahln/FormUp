# API Endpoints FormUp

**Status: Development** — seluruh endpoint auth, user, form, question, response, feedback, admin, analytics, dan **public form** sudah diimplementasikan.

## Base URL

```
http://localhost:5000/api
```

## Response Format

Semua response menggunakan wrapper `ApiResponse<T>`:

```json
{
  "status": 200,
  "message": "...",
  "data": { ... }
}
```

---

Dokumentasi endpoint dipecah per grup agar mudah dibaca:

| Grup | File |
|------|------|
| Auth (register, login, OTP, reset password) | [endpoints/auth.md](./endpoints/auth.md) |
| User Profile | [endpoints/users.md](./endpoints/users.md) |
| Reference (form types, statuses, question types) | [endpoints/references.md](./endpoints/references.md) |
| Form | [endpoints/forms.md](./endpoints/forms.md) |
| Public Form (responden, tanpa login) | [endpoints/public-forms.md](./endpoints/public-forms.md) |
| Question | [endpoints/questions.md](./endpoints/questions.md) |
| Response | [endpoints/responses.md](./endpoints/responses.md) |
| Feedback | [endpoints/feedback.md](./endpoints/feedback.md) |
| Admin | [endpoints/admin.md](./endpoints/admin.md) |
| Analytics | [endpoints/analytics.md](./endpoints/analytics.md) |
| Template | [endpoints/templates.md](./endpoints/templates.md) |
| Planned (belum diimplementasikan) | [endpoints/planned.md](./endpoints/planned.md) |
