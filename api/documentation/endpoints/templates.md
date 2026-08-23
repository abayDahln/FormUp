# Template Endpoints (Sudah Diimplementasikan)


## 1. Download Template Import Soal

`GET /api/templates/import-questions?format=csv`

**Headers:** tidak perlu auth

Download template untuk import soal. Format: `csv`, `xlsx`, `docx`, `pdf`. Format lain → `400`.

**Rate limit:** policy `template` — maksimal **10 download/menit per IP** (file digenerate on-the-fly di server sehingga relatif mahal). Melebihi → `429 Too many requests`.

Returns file langsung (Content-Disposition: attachment):
| Format | Content-Type | Nama file |
|--------|--------------|-----------|
| csv | text/csv | import-questions-template.csv |
| xlsx | application/vnd.openxmlformats-officedocument.spreadsheetml.sheet | import-questions-template.xlsx |
| docx | application/vnd.openxmlformats-officedocument.wordprocessingml.document | import-questions-template.docx |
| pdf | application/pdf | import-questions-template.pdf |

---

