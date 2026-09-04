using System.Security.Claims;
using FormUpAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Services;

/// <summary>
/// Logika bersama untuk exam-monitoring: pencatatan event incremental,
/// penautan sesi ke response saat submit, dan perakitan data monitoring.
/// Satu-satunya tempat yang menghitung pelanggaran di sisi server:
/// 1 baris <see cref="ExamViolationLog"/> = 1 pelanggaran. Client cukup
/// mengirim 1 event per 1 kejadian (jangan kirim event "kembali/focus").
/// </summary>
public static class ExamViolationTracker
{
    public static string ResolveRespondentName(ClaimsPrincipal user, string? bodyName)
    {
        if (user.Identity?.IsAuthenticated == true)
        {
            var fullname = user.FindFirst("fullname")?.Value
                ?? user.FindFirst(ClaimTypes.Name)?.Value;
            if (!string.IsNullOrWhiteSpace(fullname))
                return fullname;
        }
        return string.IsNullOrWhiteSpace(bodyName) ? "Anonim" : bodyName.Trim();
    }

    public static int? ResolveRespondentId(ClaimsPrincipal user)
    {
        var claim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return !string.IsNullOrEmpty(claim) && int.TryParse(claim, out var uid) ? uid : null;
    }

    public static bool ShouldAutoSubmit(Form form, int tabSwitchCount) =>
        form.FormSetting?.AutoSubmitOnTabSwitch == true
        && (form.FormSetting?.MaxTabSwitch ?? 0) > 0
        && tabSwitchCount >= form.FormSetting!.MaxTabSwitch;

    /// <summary>
    /// Dipanggil dari ResponseSubmission setelah response dibuat:
    /// menautkan sesi, mem-backfill ResponseId pada log yatim, menyimpan
    /// batch violations dari body, dan mengisi Response.TabSwitchCount.
    /// </summary>
    public static async Task AttachToResponseAsync(
        FormUpDbContext db, ClaimsPrincipal user, int formId,
        Response response, SubmitResponseRequest body)
    {
        ExamSession? session = null;
        var sessionKey = body.ExamSessionId?.Trim();
        if (!string.IsNullOrEmpty(sessionKey))
        {
            session = await db.ExamSessions
                .FirstOrDefaultAsync(s => s.FormId == formId && s.SessionId == sessionKey);
            if (session == null)
            {
                session = new ExamSession
                {
                    FormId = formId,
                    SessionId = sessionKey,
                    RespondentId = ResolveRespondentId(user),
                    RespondentName = ResolveRespondentName(user, body.RespondentName),
                    StartedAt = DateTime.UtcNow,
                    LastSeenAt = DateTime.UtcNow,
                    CreatedAt = DateTime.UtcNow,
                };
                db.ExamSessions.Add(session);
                await db.SaveChangesAsync();
            }
        }

        // Batch violations dari body (client yang tidak sempat kirim incremental).
        var batchLogs = new List<ExamViolationLog>();
        foreach (var v in body.Violations ?? new())
        {
            var type = ExamEventTypes.Normalize(v.Type ?? "");
            if (!ExamEventTypes.IsViolation(type)) continue;
            batchLogs.Add(new ExamViolationLog
            {
                ExamSessionId = session?.Id ?? 0,
                ResponseId = response.Id,
                ViolationType = type,
                OccurredAt = v.OccurredAt ?? DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow,
            });
        }
        // Batch tanpa sesi: buat sesi implisit agar tidak yatim.
        if (batchLogs.Count > 0 && session == null)
        {
            session = new ExamSession
            {
                FormId = formId,
                SessionId = Guid.NewGuid().ToString(),
                RespondentId = ResolveRespondentId(user),
                RespondentName = ResolveRespondentName(user, body.RespondentName),
                StartedAt = batchLogs.Min(l => l.OccurredAt) ?? DateTime.UtcNow,
                LastSeenAt = DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow,
            };
            db.ExamSessions.Add(session);
            await db.SaveChangesAsync();
            foreach (var l in batchLogs) l.ExamSessionId = session.Id;
        }
        if (batchLogs.Count > 0)
            db.ExamViolationLogs.AddRange(batchLogs);

        int serverTabSwitches = batchLogs.Count(l => l.ViolationType == ExamEventTypes.TabSwitch);
        if (session != null)
        {
            session.SubmittedResponseId = response.Id;
            session.LastSeenAt = DateTime.UtcNow;
            session.UpdatedAt = DateTime.UtcNow;
            if (session.RespondentId == null)
                session.RespondentId = ResolveRespondentId(user);

            // Backfill log yatim milik sesi ini ke response baru.
            var orphans = await db.ExamViolationLogs
                .Where(l => l.ExamSessionId == session.Id && l.ResponseId == null)
                .ToListAsync();
            foreach (var o in orphans) o.ResponseId = response.Id;

            serverTabSwitches += orphans.Count(o => o.ViolationType == ExamEventTypes.TabSwitch);
        }

        // TabSwitchCount final: prioritas kiriman client eksplisit, fallback hitungan server.
        response.TabSwitchCount = body.TabSwitchCount.HasValue && body.TabSwitchCount.Value >= 0
            ? body.TabSwitchCount.Value
            : serverTabSwitches;
    }
}
