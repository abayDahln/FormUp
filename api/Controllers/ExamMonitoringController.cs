using System.Security.Claims;
using FormUpAPI.Models;
using FormUpAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

/// <summary>
/// Monitoring mode ujian: lapor event pelanggaran incremental (real-time)
/// dan pantauan live untuk owner form.
/// </summary>
[ApiController]
public class ExamMonitoringController : ControllerBase
{
    private readonly FormUpDbContext _db;

    /// <summary>Sesi dianggap online bila ada event dalam N detik terakhir.</summary>
    private const int OnlineThresholdSeconds = 90;

    public ExamMonitoringController(FormUpDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Kirim 1 event mode ujian secara real-time (dipanggil frontend tiap
    /// kejadian, + heartbeat berkala + session_start saat mulai mengerjakan).
    /// ATURAN COUNTING: 1 event pelanggaran = 1 pelanggaran di server.
    /// Client wajib mengirim tepat 1 event per 1 siklus keluar-masuk —
    /// hanya saat pergi (hidden/blur/pause), JANGAN kirim saat kembali
    /// (visible/focus/resume) agar tidak terhitung ganda.
    /// </summary>
    [HttpPost("api/public/forms/{formLink}/exam-events")]
    [AllowAnonymous]
    [EnableRateLimiting("submit")]
    public async Task<ActionResult<ApiResponse<object>>> PostExamEvent(
        string formLink, [FromBody] ExamEventRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Type))
            return BadRequest(new ApiResponse<object>(400, "Field type wajib diisi"));

        var type = ExamEventTypes.Normalize(request.Type);
        if (!ExamEventTypes.IsKnown(type))
            return BadRequest(new ApiResponse<object>(400,
                $"Tipe event tidak dikenal: {request.Type}. " +
                "Gunakan: session_start, heartbeat, tab_switch, window_blur, copy_attempt, paste_attempt, context_menu"));

        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.FormLink == formLink && f.DeletedAt == null);

        if (form == null || form.TakenDownAt != null)
            return NotFound(new ApiResponse<object>(404, "Form tidak ditemukan"));

        var publishedStatus = await _db.FormStatuses.FirstAsync(s => s.Status == "published");
        if (form.StatusId != publishedStatus.Id)
            return NotFound(new ApiResponse<object>(404, "Form tidak ditemukan"));

        if (form.FormSetting?.IsExamMode != true && form.FormSetting?.DetectTabSwitch != true)
            return BadRequest(new ApiResponse<object>(400, "Form tidak dalam mode ujian"));

        // Owner tidak boleh tercatat sebagai peserta.
        var ownerClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(ownerClaim) && int.TryParse(ownerClaim, out var ownerUid) && form.UserId == ownerUid)
            return BadRequest(new ApiResponse<object>(400, "Anda tidak dapat mengisi form yang Anda buat sendiri"));

        var now = DateTime.UtcNow;
        var respondentId = ExamViolationTracker.ResolveRespondentId(User);
        var respondentName = ExamViolationTracker.ResolveRespondentName(User, request.RespondentName);

        ExamSession? session = null;
        var sessionKey = request.SessionId?.Trim();
        if (!string.IsNullOrEmpty(sessionKey))
        {
            session = await _db.ExamSessions
                .FirstOrDefaultAsync(s => s.FormId == form.Id && s.SessionId == sessionKey);
        }
        if (session == null)
        {
            sessionKey = string.IsNullOrEmpty(sessionKey) ? Guid.NewGuid().ToString() : sessionKey;
            session = new ExamSession
            {
                FormId = form.Id,
                SessionId = sessionKey,
                RespondentId = respondentId,
                RespondentName = respondentName,
                StartedAt = now,
                LastSeenAt = now,
                CreatedAt = now,
            };
            _db.ExamSessions.Add(session);
            await _db.SaveChangesAsync();
        }
        else
        {
            session.LastSeenAt = now;
            session.UpdatedAt = now;
            if (session.RespondentId == null) session.RespondentId = respondentId;
            if (string.IsNullOrWhiteSpace(session.RespondentName) && !string.IsNullOrWhiteSpace(respondentName))
                session.RespondentName = respondentName;
        }

        if (ExamEventTypes.IsViolation(type))
        {
            _db.ExamViolationLogs.Add(new ExamViolationLog
            {
                ExamSessionId = session.Id,
                ResponseId = session.SubmittedResponseId,
                ViolationType = type,
                OccurredAt = request.OccurredAt ?? now,
                CreatedAt = now,
            });
            session.LastSeenAt = now;
            session.UpdatedAt = now;
            await _db.SaveChangesAsync();
        }
        else
        {
            await _db.SaveChangesAsync();
        }

        var counts = await _db.ExamViolationLogs
            .Where(l => l.ExamSessionId == session.Id)
            .GroupBy(l => l.ViolationType)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToListAsync();

        var total = counts.Sum(c => c.Count);
        var tabSwitches = counts
            .Where(c => c.Key == ExamEventTypes.TabSwitch)
            .Sum(c => c.Count);

        return Ok(new ApiResponse<object>(200, "OK", new ExamEventResult
        {
            SessionId = session.SessionId,
            ViolationCount = total,
            TabSwitchCount = tabSwitches,
            ShouldAutoSubmit = ExamViolationTracker.ShouldAutoSubmit(form, tabSwitches),
        }));
    }

    /// <summary>
    /// Pantauan live mode ujian untuk owner: status tiap responden
    /// (in_progress / submitted), jumlah + timestamp tiap pelanggaran.
    /// Dirancang untuk di-polling berkala dari frontend (tiap 10–30 detik);
    /// sesi dianggap online bila ada event dalam 90 detik terakhir.
    /// </summary>
    [HttpGet("api/forms/{formId}/exam-monitoring")]
    public async Task<ActionResult<ApiResponse<object>>> GetExamMonitoring(int formId)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == formId && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        if (form.UserId != user.Id && user.Role != "ADMIN")
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var now = DateTime.UtcNow;
        var onlineSince = now.AddSeconds(-OnlineThresholdSeconds);

        var sessions = await _db.ExamSessions
            .Include(s => s.ViolationLogs)
            .Where(s => s.FormId == formId)
            .OrderByDescending(s => s.LastSeenAt)
            .ToListAsync();

        var submittedResponseIds = sessions
            .Where(s => s.SubmittedResponseId.HasValue)
            .Select(s => s.SubmittedResponseId!.Value)
            .ToList();

        var submittedAtMap = submittedResponseIds.Count > 0
            ? await _db.Responses
                .Where(r => submittedResponseIds.Contains(r.Id))
                .ToDictionaryAsync(r => r.Id, r => r.SubmittedAt ?? r.CreatedAt)
            : new Dictionary<int, DateTime?>();

        var items = sessions.Select(s =>
        {
            var logs = s.ViolationLogs.OrderBy(l => l.OccurredAt ?? l.CreatedAt).ToList();
            var submitted = s.SubmittedResponseId.HasValue;
            return new ExamMonitoringSessionDto
            {
                SessionId = s.SessionId,
                ResponseId = s.SubmittedResponseId,
                RespondentName = s.Respondent?.Fullname ?? s.RespondentName,
                RespondentId = s.RespondentId,
                Status = submitted ? "submitted" : "in_progress",
                IsOnline = !submitted && (s.LastSeenAt ?? s.CreatedAt) >= onlineSince,
                StartedAt = s.StartedAt,
                LastSeenAt = s.LastSeenAt,
                SubmittedAt = submitted && submittedAtMap.TryGetValue(s.SubmittedResponseId!.Value, out var sa) ? sa : null,
                ViolationCount = logs.Count,
                TabSwitchCount = logs.Count(l => l.ViolationType == ExamEventTypes.TabSwitch),
                Violations = logs.Select(l => new ExamMonitoringViolationDto
                {
                    Type = l.ViolationType,
                    OccurredAt = l.OccurredAt ?? l.CreatedAt,
                }).ToList(),
            };
        }).ToList();

        // Respons yang disubmit tanpa sesi (mis. client lama / tanpa exam-events):
        // tetap tampil agar owner melihat status submit yang lengkap.
        var orphanResponses = await _db.Responses
            .Include(r => r.Respondent)
            .Include(r => r.ExamViolationLogs)
            .Where(r => r.FormId == formId
                && !submittedResponseIds.Contains(r.Id)
                && !_db.ExamSessions.Any(s => s.SubmittedResponseId == r.Id))
            .OrderByDescending(r => r.SubmittedAt)
            .ToListAsync();

        foreach (var r in orphanResponses)
        {
            var logs = r.ExamViolationLogs.OrderBy(l => l.OccurredAt ?? l.CreatedAt).ToList();
            items.Add(new ExamMonitoringSessionDto
            {
                SessionId = null,
                ResponseId = r.Id,
                RespondentName = r.Respondent?.Fullname ?? r.RespondentName,
                RespondentId = r.RespondentId,
                Status = "submitted",
                IsOnline = false,
                StartedAt = r.CreatedAt,
                LastSeenAt = r.SubmittedAt ?? r.UpdatedAt,
                SubmittedAt = r.SubmittedAt ?? r.CreatedAt,
                ViolationCount = logs.Count,
                TabSwitchCount = r.TabSwitchCount ?? logs.Count(l => l.ViolationType == ExamEventTypes.TabSwitch),
                Violations = logs.Select(l => new ExamMonitoringViolationDto
                {
                    Type = l.ViolationType,
                    OccurredAt = l.OccurredAt ?? l.CreatedAt,
                }).ToList(),
            });
        }

        return Ok(new ApiResponse<object>(200, "OK", new
        {
            formId,
            isExamMode = form.FormSetting?.IsExamMode,
            detectTabSwitch = form.FormSetting?.DetectTabSwitch,
            autoSubmitOnTabSwitch = form.FormSetting?.AutoSubmitOnTabSwitch,
            maxTabSwitch = form.FormSetting?.MaxTabSwitch,
            inProgressCount = items.Count(i => i.Status == "in_progress"),
            submittedCount = items.Count(i => i.Status == "submitted"),
            onlineCount = items.Count(i => i.IsOnline),
            sessions = items,
        }));
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }
}
