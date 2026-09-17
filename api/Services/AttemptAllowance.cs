using FormUpAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Services;

/// <summary>
/// Jatah pengisian ulang one-response (data lama dipertahankan).
/// Draft status "new" TIDAK dihitung sebagai pengisian — kalau dihitung,
/// sinkronisasi draft pertama sudah mengunci user sebelum sempat submit.
/// Bila status "new" tak dikenal (misconfig), hitung semua (fail-closed
/// seperti perilaku lama) agar one-response tak pernah bocor.
/// </summary>
public static class AttemptAllowance
{
    public static async Task<int> GetExtraAttemptsAsync(
        FormUpDbContext db, int formId, int? respondentId, string? respondentName)
    {
        var q = db.FormAttemptAllowances.Where(a => a.FormId == formId);
        if (respondentId.HasValue)
            q = q.Where(a => a.RespondentId == respondentId);
        else if (!string.IsNullOrWhiteSpace(respondentName))
            q = q.Where(a => a.RespondentId == null && a.RespondentName == respondentName);
        else
            return 0;
        return await q.SumAsync(a => (int?)a.ExtraAttempts) ?? 0;
    }

    public static async Task<int> CountSubmittedAsync(
        FormUpDbContext db, int formId, int? respondentId, string? respondentName)
    {
        var newStatusId = await ReferenceCache.GetResponseStatusIdAsync(db, "new");
        var q = db.Responses.Where(r => r.FormId == formId);
        if (newStatusId.HasValue)
            q = q.Where(r => r.StatusId != newStatusId.Value);
        if (respondentId.HasValue)
            q = q.Where(r => r.RespondentId == respondentId);
        else if (!string.IsNullOrWhiteSpace(respondentName))
            q = q.Where(r => r.RespondentId == null && r.RespondentName == respondentName);
        else
            return 0;
        return await q.CountAsync();
    }

    /// <summary>
    /// Tambah 1 jatah ulang untuk responden (upsert). Mengembalikan total extra.
    /// </summary>
    public static async Task<int> GrantExtraAttemptAsync(
        FormUpDbContext db, int formId, int? respondentId, string? respondentName)
    {
        FormAttemptAllowance? row = null;
        if (respondentId.HasValue)
            row = await db.FormAttemptAllowances
                .FirstOrDefaultAsync(a => a.FormId == formId && a.RespondentId == respondentId);
        else if (!string.IsNullOrWhiteSpace(respondentName))
            row = await db.FormAttemptAllowances
                .FirstOrDefaultAsync(a => a.FormId == formId && a.RespondentId == null && a.RespondentName == respondentName);

        if (row == null)
        {
            row = new FormAttemptAllowance
            {
                FormId = formId,
                RespondentId = respondentId,
                RespondentName = respondentName,
                ExtraAttempts = 0,
                CreatedAt = DateTime.UtcNow,
            };
            db.FormAttemptAllowances.Add(row);
        }

        row.ExtraAttempts++;
        row.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        return row.ExtraAttempts;
    }
<<<<<<< HEAD
=======

    /// <summary>
    /// Reset untuk pengerjaan ulang one-response: tambah 1 jatah ulang +
    /// bersihkan sisa draft status "new" milik responden agar percobaan baru
    /// (sesi baru) mulai bersih. Respons yang sudah tersubmit TIDAK dihapus —
    /// tetap tersimpan sebagai riwayat di daftar respons form, riwayat
    /// responden, dan endpoint attempts. Mengembalikan total extra attempts.
    /// Dipakai oleh reset sesi exam-monitoring maupun reset per-respons
    /// (form non-exam yang tidak punya sesi ujian).
    /// </summary>
    public static async Task<int> ResetForRetakeAsync(
        FormUpDbContext db, int formId, int? respondentId, string? respondentName)
    {
        var extra = await GrantExtraAttemptAsync(db, formId, respondentId, respondentName);

        var newStatusId = await ReferenceCache.GetResponseStatusIdAsync(db, "new");
        if (newStatusId.HasValue)
        {
            var drafts = await db.Responses
                .Where(r => r.FormId == formId
                    && r.StatusId == newStatusId.Value
                    && (respondentId.HasValue
                        ? r.RespondentId == respondentId
                        : r.RespondentId == null && r.RespondentName == respondentName))
                .ToListAsync();
            if (drafts.Count > 0)
            {
                var draftIds = drafts.Select(d => d.Id).ToList();
                var draftAnswers = await db.RespondentAnswers
                    .Where(a => draftIds.Contains(a.ResponseId))
                    .ToListAsync();
                db.RespondentAnswers.RemoveRange(draftAnswers);
                db.Responses.RemoveRange(drafts);
                await db.SaveChangesAsync();
            }
        }

        return extra;
    }
>>>>>>> origin/main
}
