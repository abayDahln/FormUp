# Reference Endpoints (Sudah Diimplementasikan)


Butuh JWT. Dipakai builder form untuk mengisi dropdown tipe/status.

## 1. Form Types

`GET /api/references/form-types`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": [
    { "id": 1, "type": "Single Page" },
    { "id": 2, "type": "Multi Page" }
  ]
}
```

## 2. Form Statuses

`GET /api/references/form-statuses`

```json
{
  "status": 200,
  "message": "OK",
  "data": [
    { "id": 1, "status": "Draft" },
    { "id": 2, "status": "Published" },
    { "id": 3, "status": "Closed" }
  ]
}
```

## 3. Question Types

`GET /api/references/question-types`

```json
{
  "status": 200,
  "message": "OK",
  "data": [
    { "id": 1, "type": "Essay" },
    { "id": 2, "type": "Multiple Choice" },
    { "id": 3, "type": "Checkbox" },
    { "id": 4, "type": "Date Time" },
    { "id": 5, "type": "True False" }
  ]
}
```

---

