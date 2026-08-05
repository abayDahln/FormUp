# FormUp API - Requirements Document

## 1. Ringkas Project

FormUp API adalah layanan backend yang robust dan scalable untuk platform FormUp - sebuah aplikasi pembuat form modern yang mirip Google Forms dan Quizizz. API ini memungkinkan user membuat form, mengatur pertanyaan berbagai tipe, mengumpulkan response, menganalisis data, dan membagikan form dengan mudah.

---

## 2. Functional Requirements (Fitur)

### 2.1 Autentikasi & User Management

**Register User:**
- User bisa register dengan email, username, password, fullname, birthdate (optional)
- Email harus unik dan format valid
- Username harus unik
- Password minimal 8 karakter, harus ada huruf besar, kecil, angka, dan karakter spesial
- Role default: 'user'

**Login User:**
- User login dengan email/username dan password
- Return JWT token dengan expiry 60 menit
- Support refresh token untuk perpanjangan token tanpa login ulang

**Profile Management:**
- User bisa lihat dan update profile (nama, foto, birthdate)
- User bisa ganti password
- User bisa lihat statistik (total form, total response, form published, dll)

**Role Management:**
- Role: user (regular user), admin (platform admin)
- Admin bisa manage semua user dan form
- User hanya bisa manage form sendiri

---

### 2.2 Form Management

**CRUD Form:**
- Create: Buat form baru dengan title, description, banner image
- Read: Lihat list form dengan filter dan search
- Update: Edit form details dan settings
- Delete: Soft delete form

**Form Status:**
- Draft: Form masih sedang dibuat
- Published: Form sudah live dan menerima response
- Archived: Form disembunyikan dari list aktif
- Closed: Form tidak menerima response baru

**Form Settings:**
- Show score pada selesai
- Randomize urutan pertanyaan
- Form token/password protection
- Timer duration (unlimited atau X menit)
- One response per person
- Auto close form pada waktu tertentu

**Form Actions:**
- Publish form (ubah dari draft ke published)
- Duplicate form (copy beserta semua pertanyaan)
- Close form (ubah status jadi closed)

---

### 2.3 Question Management

**Tipe Pertanyaan:**
1. Multiple Choice - Pilih satu
2. Checkbox - Pilih lebih dari satu
3. Text - Input text pendek
4. Textarea - Input text panjang
5. Dropdown - Dropdown selection
6. Rating - Bintang rating
7. Date - Date picker
8. Time - Time picker
9. File Upload - Upload file
10. Linear Scale - Skala linier

**CRUD Pertanyaan:**
- Create: Tambah pertanyaan ke form dengan opsi
- Read: Lihat semua pertanyaan dan opsinya
- Update: Edit pertanyaan, opsi, dan jawaban benar
- Delete: Hapus pertanyaan
- Reorder: Ubah urutan pertanyaan drag-and-drop

**Question Properties:**
- Question text (required)
- Question image (optional)
- Question audio (optional)
- Is required (mandatory answer)
- Correct answer (untuk quiz type)
- Randomize options
- Question order

---

### 2.4 Response Collection

**Public Submission:**
- Siapa saja bisa submit response tanpa login
- Support anonymous response
- Validasi: required field harus diisi, format email harus valid, file size limit 10MB

**Response Management:**
- View semua response dengan pagination dan filter
- View detail satu response dengan semua jawaban
- Update response status (new, reviewed, flagged)
- Search di jawaban response
- Export response (CSV, Excel, PDF)

**Response Status:**
- New: Belum direview
- Reviewed: Sudah direview
- Flagged: Ditandai perlu perhatian

---

### 2.5 Analytics & Reporting

**Form Summary Analytics:**
- Total responses
- Unique respondents
- Completion rate
- Average score
- Average time to complete
- Response trend by date dan hour
- Status distribution
- Device breakdown (desktop, mobile, tablet)

**Per-Question Analytics:**
- Response distribution dengan percentage
- Chart data (bar, pie, line chart)
- Most selected option
- Least selected option

**Performance Metrics:**
- Weekly/monthly response trends
- Engagement metrics (bounce rate, avg time)
- Referral sources (direct, email, social, QR code)

---

### 2.6 Template Management

**Pre-built Templates:**
- Kategori: Survey, Quiz, Feedback, Registration, Lead Generation
- Browse dan search templates
- Apply template untuk create form baru

**Custom Templates:**
- User bisa save form mereka sebagai template
- Update/delete custom template
- Mark template as premium

---

### 2.7 Sharing & Distribution

**Sharing Methods:**
- Full link: https://formup.com/forms/xxx
- Short link: https://formup.com/f/xxx
- QR code untuk mobile scanning
- Embed code untuk website integration
- Social media share (Facebook, Twitter, LinkedIn, WhatsApp)
- Email template

**Access Control:**
- Public: Siapa saja bisa akses dengan link
- Restricted: Hanya logged-in user
- Token/Password Protected: Butuh token khusus

---

### 2.8 Webhook Integration

**Webhook Events:**
- response.submitted - Response baru dikirim
- response.updated - Status response diubah
- form.published - Form dipublikasikan
- form.closed - Form ditutup

**Features:**
- Register webhook URL
- Configure event subscriptions
- Secure dengan secret
- Retry mechanism untuk failed delivery

---

### 2.9 File Upload

**Supported File Types:**
- Image: JPG, PNG, GIF, SVG, WebP
- Document: PDF, DOC, DOCX, XLS, XLSX
- Audio: MP3, WAV, OGG
- Video: MP4, AVI, MOV
- File size limit: 10MB per file

**Upload Locations:**
- Form banner image
- Question image/audio
- Response file answers

---

## 3. Non-Functional Requirements

### 3.1 Performance

| Metric | Target |
|--------|--------|
| API Response Time (p95) | < 200ms |
| Database Query Time | < 50ms |
| Form Page Load | < 3 seconds |
| Concurrent Users | 10,000+ |
| File Upload (10MB) | < 2 seconds |
| Form Submission | < 500ms |

### 3.2 Scalability

- Horizontal scaling: Support multiple API instances
- Database: Read replicas untuk heavy read operations
- Caching: Redis untuk frequently accessed data
- CDN: Static assets via CDN
- Load balancing: Distribute traffic

### 3.3 Security

- HTTPS: All traffic encrypted
- Authentication: JWT dengan secure secret
- Authorization: Role-based access control (RBAC)
- Password: bcrypt hashing
- Rate Limiting: 100 requests/minute for free tier
- Input Validation: Prevent SQL injection & XSS
- CSRF Protection
- GDPR Compliance

### 3.4 Reliability

- Uptime: 99.9% SLA
- Backups: Automated daily backups
- Disaster Recovery: Recovery time < 1 hour
- Error Handling: Graceful dengan meaningful messages
- Logging: Structured logging untuk debugging
- Monitoring: Health checks, performance monitoring, alerts

### 3.5 Usability

- API Consistency: RESTful principles
- Documentation: Comprehensive API docs
- Error Messages: Clear dan descriptive
- Versioning: API version support
- Mobile First: Optimized untuk mobile clients

### 3.6 Maintainability

- Modular Architecture: Clear separation of concerns
- Testing: Unit, integration, E2E tests
- Code Quality: Clean code principles
- CI/CD: Automated testing & deployment
- Dependency Management: Regular updates

---

## 4. Technical Stack

### Framework & Language
- .NET 8.0
- C# 12.0
- ASP.NET Core 8.0

### Database
- SQL Server 2022
- Entity Framework Core 8.0 (ORM)

### Authentication
- JWT (JSON Web Tokens)

### Validation
- FluentValidation

### Logging
- Serilog

### API Documentation
- Swagger/OpenAPI

### File Storage
- AWS S3 / Google Cloud Storage / Azure Blob

### Caching
- Redis (optional tapi recommended)

### Dependencies
```
Microsoft.EntityFrameworkCore.SqlServer
Microsoft.AspNetCore.Authentication.JwtBearer
FluentValidation.AspNetCore
Serilog.AspNetCore
Swashbuckle.AspNetCore
Microsoft.AspNetCore.Identity
```

---

## 5. Database Schema

### Core Tables

**Users**
- id (UUID, PK)
- fullname, username, email (unique)
- password_hash, role
- birthdate, profile_image
- is_active, created_at, updated_at, deleted_at

**Forms**
- id (UUID, PK)
- user_id (FK)
- status_id (FK)
- title, description, banner_image, form_link (unique)
- created_at, updated_at, deleted_at

**Questions**
- id (UUID, PK)
- form_id (FK)
- type_id (FK)
- question, question_order
- question_image, question_audio
- is_required, correct_answer, randomize_options
- created_at, updated_at, deleted_at

**OptionQuestions**
- id (UUID, PK)
- question_id (FK)
- option_order, option_text, option_image
- is_correct
- created_at, updated_at

**Responses**
- id (UUID, PK)
- form_id (FK)
- respondent_id (FK, nullable) — null untuk guest
- respondent_name (nullable) — nama tamu opsional
- guest_token (nullable) — pengenal guest (one-response & ambil hasil)
- status_id (FK)
- submitted_at, created_at, updated_at

**RespondentAnswers**
- id (UUID, PK)
- response_id (FK)
- question_id (FK)
- option_id (FK, nullable)
- answer_value (nullable)
- created_at, updated_at

**FormSettings**
- id (UUID, PK)
- form_id (FK)
- show_score, randomize_questions
- form_token, timer_duration
- one_response, required_login
- open_form_time (set-once), close_form_time (bisa di-update)
- created_at, updated_at

### Reference Tables
- FormStatus (Draft, Published, Closed)
- QuestionType (Essay, Multiple Choice, Checkbox, Date Time, True False)
- ResponseStatus (In Progress, Submitted, new)

---

## 6. API Design

### Response Format

**Success (2xx):**
```json
{
  "data": { ... },
  "pagination": { ... },
  "meta": { ... }
}
```

**Error (4xx, 5xx):**
```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Validation failed",
  "details": { ... },
  "trace_id": "1234567890"
}
```

### Status Codes
- 200 OK - Success
- 201 Created - Resource created
- 204 No Content - Success, no data
- 400 Bad Request - Invalid request
- 401 Unauthorized - Auth failed
- 403 Forbidden - No permission
- 404 Not Found - Resource not found
- 409 Conflict - Resource conflict
- 422 Unprocessable Entity - Validation error
- 429 Too Many Requests - Rate limited
- 500 Internal Server Error - Server error

### Rate Limiting
- Free Tier: 100 requests/minute
- Premium Tier: 1,000 requests/minute
- Headers: X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset

---

## 7. Security Requirements

### Authentication
- JWT token dengan 60 menit expiry
- Refresh token support
- Invalid tokens di blacklist
- Logout invalidates token

### Authorization
- Role-based access control
- Resource-based permissions
- Admin full access
- Users access own resources

### Data Protection
- Passwords hashed dengan bcrypt
- Sensitive data encrypted at rest
- SSL/TLS untuk komunikasi
- GDPR compliance ready

### Audit Logging
- Log authentication attempts
- Log important operations (create, update, delete)
- Log access ke sensitive data
- Log API requests untuk debugging

---

## 8. Deployment Requirements

### Environment Setup
- Development, Staging, Production
- Feature flags
- Configuration via environment variables

### CI/CD Pipeline
- Automated testing pada PR
- Automated build & package
- Automated deployment ke staging
- Manual approval untuk production

### Monitoring
- Health check endpoint
- Performance monitoring
- Application logging
- Critical alerts

### Backup Strategy
- Daily database backups
- File storage backups
- Disaster recovery plan
- Monthly restore testing

---

## 9. Success Metrics

### API Metrics
- Response Time: < 200ms (p95)
- Availability: 99.9% uptime
- Error Rate: < 1% requests
- Throughput: 1000+ requests/second
- Concurrent Users: 10,000+

### Business Metrics
- Daily Active Users: 1,000+
- Forms Created: 100+/day
- Responses Collected: 10,000+/day
- API Adoptions: 50+ integrations

### Developer Experience
- API Documentation: Complete & up-to-date
- SDKs: Untuk popular languages
- Tutorials: Step-by-step guides
- Postman Collection: Ready-to-use

---

## 10. Roadmap

### Phase 1: MVP (Current)
- Core form management
- Multiple question types
- Response collection
- Basic analytics
- User authentication

### Phase 2: Enhancement (Q2 2026)
- Template library
- Conditional logic
- Advanced analytics
- Export capabilities
- Webhook support

### Phase 3: Scale (Q3 2026)
- Mobile application
- Third-party integrations
- Enterprise features
- Team collaboration

### Phase 4: Monetization (Q4 2026)
- Premium features
- Subscription plans
- Enterprise licenses
- API rate limits

---

## 11. Glossary

| Term | Meaning |
|------|---------|
| API | Application Programming Interface |
| JWT | JSON Web Token |
| RBAC | Role-Based Access Control |
| CRUD | Create, Read, Update, Delete |
| GDPR | General Data Protection Regulation |
| SLA | Service Level Objective |
| CDN | Content Delivery Network |
| CI/CD | Continuous Integration/Deployment |
| ORM | Object-Relational Mapping |
| UUID | Universally Unique Identifier |
| FK | Foreign Key |
| E2E | End-to-End Testing |
| WAF | Web Application Firewall |
| RTO | Recovery Time Objective |
| RPO | Recovery Point Objective |

---

## Document Info

- Version: 1.0
- Last Updated: January 15, 2026
- Status: Active
- Next Review: February 15, 2026