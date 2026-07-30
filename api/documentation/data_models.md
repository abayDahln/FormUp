# Data Models

## 1. User (Pengguna)

Menyimpan data user dan akun.

| Field | Type | Required | Unique | Keterangan |
|-------|------|----------|--------|-----------|
| id | int | Ya | Ya | Primary key (auto-increment) |
| fullname | string(100) | Ya | Tidak | Nama lengkap user |
| username | string(50) | Ya | Ya | Username untuk login |
| email | string(100) | Ya | Ya | Email address |
| password | string(255) | Ya | Tidak | Hash password (PBKDF2 SHA256, format `salt.hash`) |
| role | string(20) | Tidak | Tidak | `"USER"` default, bisa juga `"ADMIN"` |
| birthdate | date | Tidak | Tidak | Tanggal lahir |
| profile_image | string(255) | Tidak | Tidak | Path foto profil (contoh: `/profile/xxx.jpg`) |
| is_active | boolean | Tidak | Tidak | Default: true |
| created_at | datetime | Ya | Tidak | Waktu dibuat |
| updated_at | datetime | Ya | Tidak | Waktu terakhir diubah |
| deleted_at | datetime | Tidak | Tidak | Soft delete (null = aktif) |

---

## 2. Form (Formulir)

Menyimpan data form yang dibuat user.

| Field | Type | Required | Unique | Keterangan |
|-------|------|----------|--------|-----------|
| id | int | Ya | Ya | Primary key (auto-increment) |
| user_id | int | Ya | Tidak | FK ke User (pemilik form) |
| status_id | int | Ya | Tidak | FK ke FormStatus (1=draft, 2=published, 3=archived, 4=closed) |
| title | string(255) | Ya | Tidak | Judul form |
| description | text | Tidak | Tidak | Deskripsi form |
| banner_image | string(255) | Tidak | Tidak | Path banner (contoh: `/banner/xxx.jpg`) |
| form_link | string(255) | Ya | Ya | Link unik untuk akses form |
| created_at | datetime | Ya | Tidak | Waktu dibuat |
| updated_at | datetime | Ya | Tidak | Waktu terakhir diubah |
| deleted_at | datetime | Tidak | Tidak | Soft delete (null = aktif) |

---

## 3. FormSetting (Pengaturan Form)

Relasi 1:1 dengan Form. Row di-auto-create saat pertama kali settings di-PATCH.

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | int | Ya | Primary key (auto-increment) |
| form_id | int | Ya | FK ke Form |
| show_score | boolean | Tidak | Tampilkan score setelah submit (default: false) |
| randomize_questions | boolean | Tidak | Acak urutan pertanyaan (default: false) |
| form_token | string(255) | Tidak | Token/password untuk akses form |
| timer_duration | int | Tidak | Batas waktu pengerjaan (menit, 0 = unlimited) |
| one_response | boolean | Tidak | Batasi 1 response per orang (default: false) |
| close_form_time | datetime | Tidak | Form otomatis tutup pada waktu ini |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |

---

## 4. Question (Pertanyaan)

Menyimpan pertanyaan dalam form.

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | int | Ya | Primary key (auto-increment) |
| form_id | int | Ya | FK ke Form |
| type_id | int | Ya | FK ke QuestionType (lihat tabel referensi) |
| question | text | Ya | Teks pertanyaan |
| question_order | int | Ya | Urutan pertanyaan (mulai dari 1) |
| question_image | string(255) | Tidak | URL gambar pertanyaan |
| question_audio | string(255) | Tidak | URL audio pertanyaan |
| is_required | boolean | Tidak | Wajib dijawab (default: false) |
| correct_answer | string(255) | Tidak | Jawaban benar (untuk quiz) |
| randomize_options | boolean | Tidak | Acak urutan opsi (default: false) |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |
| deleted_at | datetime | Tidak | Soft delete (null = aktif) |

---

## 5. OptionQuestion (Opsi Pertanyaan)

Opsi untuk tipe multiple_choice, checkbox, dan dropdown.

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | int | Ya | Primary key (auto-increment) |
| question_id | int | Ya | FK ke Question |
| option_order | int | Ya | Urutan opsi (mulai dari 1) |
| option_text | string(500) | Ya | Teks opsi |
| option_image | string(255) | Tidak | URL gambar opsi |
| is_correct | boolean | Tidak | Apakah ini jawaban benar (default: false) |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |

---

## 6. Response (Respon Form)

Satu submission dari form oleh responden.

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | int | Ya | Primary key (auto-increment) |
| form_id | int | Ya | FK ke Form |
| respondent_id | int | Tidak | FK ke User (null untuk anonymous) |
| status_id | int | Ya | FK ke ResponseStatus (1=new, 2=reviewed, 3=flagged) |
| submitted_at | datetime | Ya | Waktu respon disubmit |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |

---

## 7. RespondentAnswer (Jawaban Responden)

Jawaban individual untuk setiap pertanyaan dalam satu Response.

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | int | Ya | Primary key (auto-increment) |
| response_id | int | Ya | FK ke Response |
| question_id | int | Ya | FK ke Question |
| option_id | int | Tidak | FK ke OptionQuestion (jika pilih opsi) |
| answer_value | text | Tidak | Jawaban text (jika text input) |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |

---

## 8. Tabel Referensi (Data Statis)

Tabel-tabel ini diisi saat migrasi dan hanya dibaca (read-only).

### FormStatus

| ID | Status | Keterangan |
|----|--------|-----------|
| 1 | draft | Form masih draft, belum dipublikasi |
| 2 | published | Form sudah dipublikasi dan aktif |
| 3 | archived | Form diarsipkan |
| 4 | closed | Form ditutup, tidak menerima response baru |

### QuestionType

| ID | Type | Keterangan |
|----|------|-----------|
| 1 | multiple_choice | Pilih satu dari beberapa opsi |
| 2 | checkbox | Pilih lebih dari satu opsi |
| 3 | text | Input text pendek |
| 4 | textarea | Input text panjang |
| 5 | dropdown | Dropdown selection |
| 6 | rating | Rating bintang |
| 7 | date | Date picker |
| 8 | time | Time picker |
| 9 | file_upload | File upload |
| 10 | linear_scale | Linear scale selection |

### ResponseStatus

| ID | Status | Keterangan |
|----|--------|-----------|
| 1 | new | Respon baru, belum direview |
| 2 | reviewed | Respon sudah direview |
| 3 | flagged | Respon ditandai perlu perhatian khusus |

---

## 9. Entity Relationships

```
User (1) ---< (N) Form
  |
  +--- (1) ---< (N) Response

Form (1) ---< (N) Question
Form (1) ---  (1) FormSetting
Form (1) ---  (1) FormStatus

Question (1) ---< (N) OptionQuestion
Question (1) ---< (N) RespondentAnswer
Question (1) ---  (1) QuestionType

Response (1) ---< (N) RespondentAnswer
Response (1) ---  (1) ResponseStatus

OptionQuestion (1) ---< (N) RespondentAnswer
```

> Semua primary key menggunakan `int` auto-increment. Tidak ada UUID.

---

## 10. Aturan Umum

| Aturan | Keterangan |
|--------|-----------|
| Soft delete | Semua entitas utama punya `deleted_at`. Jangan hapus baris, set `deleted_at` saja. |
| Password | Format `salt.hash` — PBKDF2 dengan SHA256, 100.000 iterasi. |
| Unique | `email` dan `username` di User, `form_link` di Form. |
| Timestamps | `created_at` dan `updated_at` diisi otomatis oleh database (`GETDATE()`). |
