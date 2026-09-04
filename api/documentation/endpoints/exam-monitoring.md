# Exam Monitoring — Mode Ujian (Sudah Diimplementasikan)

Pemantauan real-time/near-real-time responden yang mengerjakan form
ber-mode ujian, plus pencatatan pelanggaran yang akurat di sisi server.

## Konsep

- **Sumber kebenaran ada di server.** Setiap baris `ExamViolationLog`
  = 1 pelanggaran. Klien (web/mobile) hanya mengirim event, tidak
  menghitung sendiri untuk keperluan owner.
- **Aturan counting (PENTING, anti double-count):** 1 event masuk = 1
  pelanggaran. Klien wajib mengirim tepat **1 event per 1 siklus
  keluar-masuk**: hanya saat *pergi* (`visibilitychange → hidden` /
  `window blur` di web, `AppLifecycleState.paused` di Flutter) —
  **jangan** kirim event saat *kembali* (`visible`/`focus`/`resume`).
  Menghitung pergi + kembali sebagai dua event = bug ganda.
- **Sesi (`ExamSession`):** dibuat otomatis saat event pertama masuk.
  `sessionId` (UUID dari klien; digenerate server bila kosong) dipakai
  ulang untuk semua event dalam satu upaya pengerjaan.
- **Presence live:** klien mengirim `session_start` saat mulai +
  `heartbeat` berkala (± tiap 30 detik) + 1 event tiap pelanggaran.
  Owner me-polling endpoint monitoring (± tiap 10–30 detik); sesi
  dianggap `isOnline` bila ada event dalam 90 detik terakhir.
- **Tahan refresh/tutup tab (A-7):** data pelanggaran tersimpan di
  server, bukan client-side — refresh/ganti device tidak mereset.
  Saat submit, response ditautkan ke sesi (`examSessionId`) dan log
  yang masih yatim di-backfill `response_id`.

## 1. Kirim Event Ujian (Responden, Tanpa Login)

`POST /api/public/forms/{formLink}/exam-events`

Tanpa JWT (kecuali form `requiresLogin`). Rate limit policy `submit`
(60/menit per IP+form — cukup untuk heartbeat + burst pelanggaran).

**Request:**
```json
{
  "sessionId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "respondentName": "Budi",
  "type": "tab_switch",
  "occurredAt": "2026-09-04T10:15:30Z"
}
```

| Field | Keterangan |
|-------|------------|
| `sessionId` | UUID klien. Kosongkan pada event pertama → server generate & kembalikan; pakai ulang setelahnya |
| `respondentName` | Nama responden (opsional; diambil dari akun bila login) |
| `type` | `session_start`, `heartbeat`, `tab_switch`, `window_blur`, `copy_attempt`, `paste_attempt`, `context_menu` (alias umum seperti `blur`, `copy`, `tabswitch` diterima) |
| `occurredAt` | Waktu kejadian di klien (UTC, opsional → waktu server) |

Hanya tipe pelanggaran yang menambah baris log; `session_start` /
`heartbeat` hanya memperbarui `lastSeenAt`.

**Validasi:**
- Form harus `published` (dan lolos open/close time tidak dicek di sini —
  sama seperti submit; event hanya dicatat untuk form yang tersedia)
- Form harus mode ujian (`isExamMode` atau `detectTabSwitch = true`),
  kalau tidak → `400 Form tidak dalam mode ujian`
- Owner form tidak tercatat sebagai peserta → `400`
- Tipe tak dikenal → `400`

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "sessionId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "violationCount": 3,
    "tabSwitchCount": 2,
    "shouldAutoSubmit": false
  }
}
```

`shouldAutoSubmit = true` bila `autoSubmitOnTabSwitch = true` dan jumlah
`tab_switch` sesi sudah mencapai `maxTabSwitch` → klien harus segera
auto-submit jawaban apa adanya (berlaku juga setelah refresh, karena
hitungan diambil dari server).

---

## 2. Pantauan Live (Owner)

`GET /api/forms/{formId}/exam-monitoring`

**Headers:** `Authorization: Bearer <token>` (pemilik form atau ADMIN)

**Response 200:**
```json
{
  "status": 200,
  "message": "OK",
  "data": {
    "formId": 1,
    "isExamMode": true,
    "detectTabSwitch": true,
    "autoSubmitOnTabSwitch": true,
    "maxTabSwitch": 3,
    "inProgressCount": 2,
    "submittedCount": 5,
    "onlineCount": 1,
    "sessions": [
      {
        "sessionId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "responseId": null,
        "respondentName": "Budi",
        "respondentId": null,
        "status": "in_progress",
        "isOnline": true,
        "startedAt": "2026-09-04T10:00:00Z",
        "lastSeenAt": "2026-09-04T10:15:30Z",
        "submittedAt": null,
        "violationCount": 3,
        "tabSwitchCount": 2,
        "violations": [
          { "type": "tab_switch", "occurredAt": "2026-09-04T10:05:11Z" },
          { "type": "tab_switch", "occurredAt": "2026-09-04T10:12:02Z" },
          { "type": "copy_attempt", "occurredAt": "2026-09-04T10:15:30Z" }
        ]
      }
    ]
  }
}
```

- `status`: `in_progress` (sesi ada, belum submit) atau `submitted`.
- Respons yang disubmit **tanpa** sesi (klien lama / tanpa exam-events)
  tetap muncul sebagai entri `submitted` dengan `sessionId: null` agar
  daftar submit tetap lengkap.
- Tidak ada WebSocket/SignalR — project ini belum memakai infrastruktur
  tersebut; polling berkala sudah memenuhi kebutuhan near-real-time.

---

## 3. Submit Response — Field Tambahan Mode Ujian

`POST /api/forms/{formId}/responses` dan
`POST /api/public/forms/{formLink}/responses` menerima field tambahan
(semua opsional, backward-compat):

```json
{
  "token": null,
  "respondentName": "Budi",
  "answers": [ { "questionId": 1, "optionId": 2 } ],
  "examSessionId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "tabSwitchCount": 2,
  "violations": [
    { "type": "tab_switch", "occurredAt": "2026-09-04T10:05:11Z" }
  ]
}
```

| Field | Keterangan |
|-------|------------|
| `examSessionId` | Menautkan response ke sesi → `submittedResponseId` diisi, log yatim di-backfill `response_id` |
| `tabSwitchCount` | Total menurut klien (prioritas). Bila null → server memakai hitungan log sesi |
| `violations` | Batch pelanggaran (tipe + timestamp) untuk klien yang belum sempat kirim incremental; digabung ke log (bila tanpa sesi, sesi implisit dibuat otomatis) |

Kolom `tab_switch_count` tersimpan di tabel `Response` dan muncul di:
- `GET /api/forms/{formId}/responses` → `tabSwitchCount` per item
- `GET /api/forms/{formId}/responses/{id}` → `tabSwitchCount` + rincian
  `violations` (tipe + timestamp per kejadian)

---

## Skema Data Baru

| Tabel | Kolom kunci |
|-------|-------------|
| `ExamSession` | `id`, `form_id`, `session_id` (unique per form), `respondent_id?`, `respondent_name?`, `submitted_response_id?`, `started_at`, `last_seen_at`, `created_at`, `updated_at` |
| `ExamViolationLog` | `id`, `exam_session_id` (cascade), `response_id?` (null selama belum submit), `violation_type`, `occurred_at`, `created_at` |
| `Response` | + `tab_switch_count?` (angka ringkas; detail di `ExamViolationLog`) |

Migration: `AddExamMonitoring`. Terapkan dengan
`dotnet ef database update` (butuh `DB_CONNECTION`).
