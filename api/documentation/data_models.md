# Data Models dan Database Schema

## Entitas Utama

### 1. User (Pengguna)

Menyimpan data user dan akun.

**Fields:**

| Field | Type | Required | Unique | Keterangan |
|-------|------|----------|--------|-----------|
| id | UUID | Ya | Ya | Primary key |
| fullname | string(255) | Ya | Tidak | Nama lengkap user |
| username | string(100) | Ya | Ya | Username untuk login |
| email | string(255) | Ya | Ya | Email address |
| password_hash | string(255) | Ya | Tidak | Hash password dengan bcrypt |
| role | enum | Tidak | Tidak | user atau admin (default: user) |
| birthdate | date | Tidak | Tidak | Tanggal lahir |
| profile_image | string(500) | Tidak | Tidak | URL foto profil |
| is_active | boolean | Tidak | Tidak | User active atau tidak (default: true) |
| created_at | datetime | Ya | Tidak | Waktu dibuat |
| updated_at | datetime | Ya | Tidak | Waktu terakhir diubah |
| deleted_at | datetime | Tidak | Tidak | Waktu soft delete (null jika tidak dihapus) |

**SQL:**
```sql
CREATE TABLE Users (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    fullname NVARCHAR(255) NOT NULL,
    username NVARCHAR(100) NOT NULL UNIQUE,
    email NVARCHAR(255) NOT NULL UNIQUE,
    password_hash NVARCHAR(255) NOT NULL,
    role NVARCHAR(50) DEFAULT 'user',
    birthdate DATE NULL,
    profile_image NVARCHAR(500) NULL,
    is_active BIT DEFAULT 1,
    created_at DATETIME DEFAULT GETUTCDATE(),
    updated_at DATETIME DEFAULT GETUTCDATE(),
    deleted_at DATETIME NULL
)
```

---

### 2. Form (Formulir)

Menyimpan data form yang dibuat user.

**Fields:**

| Field | Type | Required | Unique | Keterangan |
|-------|------|----------|--------|-----------|
| id | UUID | Ya | Ya | Primary key |
| user_id | UUID | Ya | Tidak | FK ke Users |
| status_id | int | Ya | Tidak | FK ke FormStatus |
| title | string(255) | Ya | Tidak | Judul form |
| description | text | Tidak | Tidak | Deskripsi form |
| banner_image | string(500) | Tidak | Tidak | URL banner form |
| form_link | string(500) | Ya | Ya | Link unik untuk form |
| created_at | datetime | Ya | Tidak | Waktu dibuat |
| updated_at | datetime | Ya | Tidak | Waktu terakhir diubah |
| deleted_at | datetime | Tidak | Tidak | Waktu soft delete |

**SQL:**
```sql
CREATE TABLE Forms (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    user_id UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Users(id),
    status_id INT NOT NULL FOREIGN KEY REFERENCES FormStatus(id),
    title NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX) NULL,
    banner_image NVARCHAR(500) NULL,
    form_link NVARCHAR(500) NOT NULL UNIQUE,
    created_at DATETIME DEFAULT GETUTCDATE(),
    updated_at DATETIME DEFAULT GETUTCDATE(),
    deleted_at DATETIME NULL
)
```

---

### 3. FormStatus (Status Form)

Tabel referensi untuk status form.

**Reference Data:**

| ID | Status | Keterangan |
|----|--------|-----------|
| 1 | draft | Form masih draft, belum dipublikasi |
| 2 | published | Form sudah dipublikasi dan aktif |
| 3 | archived | Form diarsipkan |
| 4 | closed | Form ditutup, tidak menerima response baru |

**SQL:**
```sql
CREATE TABLE FormStatus (
    id INT PRIMARY KEY,
    status NVARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT GETUTCDATE()
)

INSERT INTO FormStatus VALUES 
(1, 'draft', GETUTCDATE()),
(2, 'published', GETUTCDATE()),
(3, 'archived', GETUTCDATE()),
(4, 'closed', GETUTCDATE())
```

---

### 4. FormSetting (Pengaturan Form)

Menyimpan pengaturan tambahan form.

**Fields:**

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | UUID | Ya | Primary key |
| form_id | UUID | Ya | FK ke Forms |
| show_score | boolean | Tidak | Tampilkan score saat selesai (default: false) |
| randomize_questions | boolean | Tidak | Acak urutan pertanyaan (default: false) |
| form_token | string(255) | Tidak | Token/password untuk akses form |
| timer_duration | int | Tidak | Waktu pengerjaan dalam menit (0 = unlimited) |
| one_response | boolean | Tidak | Hanya 1 response per person (default: false) |
| close_form_time | datetime | Tidak | Waktu form otomatis ditutup |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |

**SQL:**
```sql
CREATE TABLE FormSettings (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    form_id UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Forms(id),
    show_score BIT DEFAULT 0,
    randomize_questions BIT DEFAULT 0,
    form_token NVARCHAR(255) NULL,
    timer_duration INT DEFAULT 0,
    one_response BIT DEFAULT 0,
    close_form_time DATETIME NULL,
    created_at DATETIME DEFAULT GETUTCDATE(),
    updated_at DATETIME DEFAULT GETUTCDATE()
)
```

---

### 5. Question (Pertanyaan)

Menyimpan pertanyaan dalam form.

**Fields:**

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | UUID | Ya | Primary key |
| form_id | UUID | Ya | FK ke Forms |
| type_id | int | Ya | FK ke QuestionType |
| question | text | Ya | Teks pertanyaan |
| question_order | int | Ya | Urutan pertanyaan dalam form |
| question_image | string(500) | Tidak | URL gambar pertanyaan |
| question_audio | string(500) | Tidak | URL audio pertanyaan |
| is_required | boolean | Tidak | Pertanyaan wajib dijawab (default: false) |
| correct_answer | string(500) | Tidak | Jawaban benar (untuk quiz) |
| randomize_options | boolean | Tidak | Acak urutan opsi (default: false) |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |
| deleted_at | datetime | Tidak | Waktu soft delete |

**SQL:**
```sql
CREATE TABLE Questions (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    form_id UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Forms(id),
    type_id INT NOT NULL FOREIGN KEY REFERENCES QuestionTypes(id),
    question NVARCHAR(MAX) NOT NULL,
    question_order INT NOT NULL,
    question_image NVARCHAR(500) NULL,
    question_audio NVARCHAR(500) NULL,
    is_required BIT DEFAULT 0,
    correct_answer NVARCHAR(500) NULL,
    randomize_options BIT DEFAULT 0,
    created_at DATETIME DEFAULT GETUTCDATE(),
    updated_at DATETIME DEFAULT GETUTCDATE(),
    deleted_at DATETIME NULL
)
```

---

### 6. QuestionType (Tipe Pertanyaan)

Tabel referensi untuk tipe pertanyaan.

**Reference Data:**

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

**SQL:**
```sql
CREATE TABLE QuestionTypes (
    id INT PRIMARY KEY,
    type NVARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT GETUTCDATE()
)

INSERT INTO QuestionTypes VALUES 
(1, 'multiple_choice', GETUTCDATE()),
(2, 'checkbox', GETUTCDATE()),
(3, 'text', GETUTCDATE()),
(4, 'textarea', GETUTCDATE()),
(5, 'dropdown', GETUTCDATE()),
(6, 'rating', GETUTCDATE()),
(7, 'date', GETUTCDATE()),
(8, 'time', GETUTCDATE()),
(9, 'file_upload', GETUTCDATE()),
(10, 'linear_scale', GETUTCDATE())
```

---

### 7. OptionQuestion (Opsi Pertanyaan)

Menyimpan opsi untuk pertanyaan choice/checkbox/dropdown.

**Fields:**

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | UUID | Ya | Primary key |
| question_id | UUID | Ya | FK ke Questions |
| option_order | int | Ya | Urutan opsi |
| option_text | string(500) | Ya | Teks opsi |
| option_image | string(500) | Tidak | URL gambar opsi |
| is_correct | boolean | Tidak | Apakah opsi ini jawaban benar (untuk quiz) |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |

**SQL:**
```sql
CREATE TABLE OptionQuestions (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    question_id UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Questions(id),
    option_order INT NOT NULL,
    option_text NVARCHAR(500) NOT NULL,
    option_image NVARCHAR(500) NULL,
    is_correct BIT DEFAULT 0,
    created_at DATETIME DEFAULT GETUTCDATE(),
    updated_at DATETIME DEFAULT GETUTCDATE()
)
```

---

### 8. Response (Respon Form)

Menyimpan satu respon/submission dari form.

**Fields:**

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | UUID | Ya | Primary key |
| form_id | UUID | Ya | FK ke Forms |
| respondent_id | UUID | Tidak | FK ke Users (nullable untuk anonymous) |
| status_id | int | Ya | FK ke ResponseStatus |
| submitted_at | datetime | Ya | Waktu respon disubmit |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |

**SQL:**
```sql
CREATE TABLE Responses (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    form_id UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Forms(id),
    respondent_id UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES Users(id),
    status_id INT NOT NULL FOREIGN KEY REFERENCES ResponseStatus(id),
    submitted_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT GETUTCDATE(),
    updated_at DATETIME DEFAULT GETUTCDATE()
)
```

---

### 9. ResponseStatus (Status Respon)

Tabel referensi untuk status respon.

**Reference Data:**

| ID | Status | Keterangan |
|----|--------|-----------|
| 1 | new | Respon baru, belum direview |
| 2 | reviewed | Respon sudah direview |
| 3 | flagged | Respon ditandai perlu perhatian khusus |

**SQL:**
```sql
CREATE TABLE ResponseStatus (
    id INT PRIMARY KEY,
    status NVARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT GETUTCDATE()
)

INSERT INTO ResponseStatus VALUES 
(1, 'new', GETUTCDATE()),
(2, 'reviewed', GETUTCDATE()),
(3, 'flagged', GETUTCDATE())
```

---

### 10. RespondentAnswer (Jawaban Responden)

Menyimpan jawaban individual untuk setiap pertanyaan dalam respon.

**Fields:**

| Field | Type | Required | Keterangan |
|-------|------|----------|-----------|
| id | UUID | Ya | Primary key |
| response_id | UUID | Ya | FK ke Responses |
| question_id | UUID | Ya | FK ke Questions |
| option_id | UUID | Tidak | FK ke OptionQuestions (jika pilih opsi) |
| answer_value | text | Tidak | Jawaban text (jika text input) |
| created_at | datetime | Ya | Waktu dibuat |
| updated_at | datetime | Ya | Waktu terakhir diubah |

**SQL:**
```sql
CREATE TABLE RespondentAnswers (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    response_id UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Responses(id),
    question_id UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Questions(id),
    option_id UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES OptionQuestions(id),
    answer_value NVARCHAR(MAX) NULL,
    created_at DATETIME DEFAULT GETUTCDATE(),
    updated_at DATETIME DEFAULT GETUTCDATE()
)
```

---

## Entity Relationship Diagram

```
User (1) ---< (N) Form
  |
  +--- (1) ---< (N) Response

Form (1) ---< (N) Question
Form (1) ---< (1) FormSetting
Form (1) ---< (1) FormStatus

Question (1) ---< (N) OptionQuestion
Question (1) ---< (N) RespondentAnswer
Question (1) ---< (1) QuestionType

Response (1) ---< (N) RespondentAnswer
Response (1) ---< (1) ResponseStatus

OptionQuestion (1) ---< (N) RespondentAnswer
```

---

## Index untuk Performance

**SQL:**
```sql
-- User indexes
CREATE INDEX idx_users_email ON Users(email)
CREATE INDEX idx_users_username ON Users(username)
CREATE INDEX idx_users_deleted_at ON Users(deleted_at)

-- Form indexes
CREATE INDEX idx_forms_user_id ON Forms(user_id)
CREATE INDEX idx_forms_status_id ON Forms(status_id)
CREATE INDEX idx_forms_created_at ON Forms(created_at)
CREATE INDEX idx_forms_deleted_at ON Forms(deleted_at)

-- Question indexes
CREATE INDEX idx_questions_form_id ON Questions(form_id)
CREATE INDEX idx_questions_type_id ON Questions(type_id)

-- OptionQuestion indexes
CREATE INDEX idx_optionquestions_question_id ON OptionQuestions(question_id)

-- Response indexes
CREATE INDEX idx_responses_form_id ON Responses(form_id)
CREATE INDEX idx_responses_respondent_id ON Responses(respondent_id)
CREATE INDEX idx_responses_status_id ON Responses(status_id)
CREATE INDEX idx_responses_submitted_at ON Responses(submitted_at)

-- RespondentAnswer indexes
CREATE INDEX idx_respondent_answers_response_id ON RespondentAnswers(response_id)
CREATE INDEX idx_respondent_answers_question_id ON RespondentAnswers(question_id)
```

---

## View Useful untuk Query

### View: Form Summary

```sql
CREATE VIEW v_form_summary AS
SELECT 
    f.id,
    f.title,
    fs.status,
    u.fullname AS creator,
    (SELECT COUNT(*) FROM Responses r WHERE r.form_id = f.id) AS response_count,
    (SELECT COUNT(*) FROM Questions q WHERE q.form_id = f.id) AS question_count,
    f.created_at,
    f.updated_at
FROM Forms f
JOIN FormStatus fs ON f.status_id = fs.id
JOIN Users u ON f.user_id = u.id
WHERE f.deleted_at IS NULL
```

### View: Response Summary

```sql
CREATE VIEW v_response_summary AS
SELECT 
    r.id,
    r.form_id,
    f.title AS form_title,
    (SELECT COUNT(*) FROM RespondentAnswers ra WHERE ra.response_id = r.id) AS answered_count,
    rs.status,
    r.submitted_at,
    DATEDIFF(SECOND, r.created_at, r.submitted_at) AS submission_time_seconds
FROM Responses r
JOIN Forms f ON r.form_id = f.id
JOIN ResponseStatus rs ON r.status_id = rs.id
```

---

## Constraints & Rules

1. **Foreign Key Constraints**: Semua FK harus maintain referential integrity
2. **Unique Constraints**: email dan username di Users, form_link di Forms
3. **Not Null**: Required fields harus NOT NULL
4. **Check Constraints**: 
   - timer_duration harus >= 0
   - question_order harus > 0
   - option_order harus > 0
5. **Cascade Delete**: Jika form dihapus, hapus juga questions, responses, settings-nya (tapi use soft delete)

---

## Enum Definition (C#)

```csharp
public enum UserRole
{
    user,
    admin
}

public enum FormStatusEnum
{
    draft = 1,
    published = 2,
    archived = 3,
    closed = 4
}

public enum QuestionTypeEnum
{
    multiple_choice = 1,
    checkbox = 2,
    text = 3,
    textarea = 4,
    dropdown = 5,
    rating = 6,
    date = 7,
    time = 8,
    file_upload = 9,
    linear_scale = 10
}

public enum ResponseStatusEnum
{
    @new = 1,
    reviewed = 2,
    flagged = 3
}
```