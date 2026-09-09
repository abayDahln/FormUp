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

        var totalQuestions = await _db.Questions
            .CountAsync(q => q.FormId == formId && q.DeletedAt == null);

        var answeredMap = submittedResponseIds.Count > 0
            ? await _db.RespondentAnswers
                .Where(a => submittedResponseIds.Contains(a.ResponseId))
                .GroupBy(a => a.ResponseId)
                .Select(g => new { ResponseId = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.ResponseId, x => x.Count)
            : new Dictionary<int, int>();

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
                AnsweredCount = submitted && s.SubmittedResponseId.HasValue && answeredMap.TryGetValue(s.SubmittedResponseId.Value, out var ac) ? ac : 0,
                TotalQuestions = totalQuestions,
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
            .Include(r => r.RespondentAnswers)
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
                AnsweredCount = r.RespondentAnswers?.Count ?? 0,
                TotalQuestions = totalQuestions,
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
            totalQuestions,
            inProgressCount = items.Count(i => i.Status == "in_progress"),
            submittedCount = items.Count(i => i.Status == "submitted"),
            onlineCount = items.Count(i => i.IsOnline),
            sessions = items,
        }));
    }

    /// <summary>
    /// Paksa submit peserta ujian: sesi in_progress ditandai submitted.
    /// Spec B12 (route kanonis): POST /api/forms/{formId}/exam-monitoring/sessions/{sessionId}/force-submit.
    /// Bila ada draft jawaban dari sync-answers (Response status "new"), draft itu
    /// yang difinalisasi; bila belum ada, dibuatkan Response agar tercatat.
    /// Mencatat log <see cref="ExamProctorActions.ForceSubmitByProctor"/>.
    /// </summary>
    [HttpPost("api/forms/{formId}/exam-monitoring/sessions/{sessionId}/force-submit")]
    public Task<ActionResult<ApiResponse<object>>> ForceSubmitSpec(int formId, string sessionId)
        => DoForceSubmit(formId, sessionId);

    /// <summary>Alias kompatibilitas route lama (mobile versi lama).</summary>
    [HttpPost("api/forms/{formId}/exam/sessions/{sessionId}/force-submit")]
    public Task<ActionResult<ApiResponse<object>>> ForceSubmit(int formId, string sessionId)
        => DoForceSubmit(formId, sessionId);

    private async Task<ActionResult<ApiResponse<object>>> DoForceSubmit(int formId, string sessionId)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.DeletedAt == null);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));
        if (form.UserId != user.Id && user.Role != "ADMIN")
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var session = await _db.ExamSessions
            .FirstOrDefaultAsync(s => s.FormId == formId && s.SessionId == sessionId);
        if (session == null)
            return NotFound(new ApiResponse<object>(404, "Session not found"));
        if (session.SubmittedResponseId.HasValue)
            return BadRequest(new ApiResponse<object>(400, "Session already submitted"));

        var now = DateTime.UtcNow;

        // Finalisasi draft dari sync-answers bila ada (status "new" milik responden sesi).
        Response? response = null;
        var newStatus = await _db.ResponseStatuses.FirstOrDefaultAsync(s => s.Status == "new");
        if (newStatus != null)
        {
            var draftQuery = _db.Responses
                .Include(r => r.RespondentAnswers)
                .Where(r => r.FormId == formId && r.StatusId == newStatus.Id);
            response = session.RespondentId.HasValue
                ? await draftQuery.OrderByDescending(r => r.CreatedAt)
                    .FirstOrDefaultAsync(r => r.RespondentId == session.RespondentId)
                : (!string.IsNullOrWhiteSpace(session.RespondentName)
                    ? await draftQuery.OrderByDescending(r => r.CreatedAt)
                        .FirstOrDefaultAsync(r => r.RespondentId == null && r.RespondentName == session.RespondentName)
                    : null);
        }

        var submittedStatus = await _db.ResponseStatuses
            .FirstOrDefaultAsync(s => s.Status == "submitted")
            ?? await _db.ResponseStatuses.FirstOrDefaultAsync();

        if (response == null)
        {
            response = new Response
            {
                FormId = formId,
                RespondentId = session.RespondentId,
                RespondentName = session.RespondentName,
                StatusId = submittedStatus?.Id ?? 1,
                SubmittedAt = now,
                CreatedAt = now,
                UpdatedAt = now,
            };
            _db.Responses.Add(response);
            await _db.SaveChangesAsync();
        }
        else
        {
            response.StatusId = submittedStatus?.Id ?? response.StatusId;
            response.SubmittedAt = now;
            response.UpdatedAt = now;
            await _db.SaveChangesAsync();
        }

        session.SubmittedResponseId = response.Id;
        session.LastSeenAt = now;
        session.UpdatedAt = now;

        // Backfill log pelanggaran yatim ke response hasil force-submit.
        var orphans = await _db.ExamViolationLogs
            .Where(l => l.ExamSessionId == session.Id && l.ResponseId == null)
            .ToListAsync();
        foreach (var l in orphans) l.ResponseId = response.Id;

        _db.ExamViolationLogs.Add(new ExamViolationLog
        {
            ExamSessionId = session.Id,
            ResponseId = response.Id,
            ViolationType = ExamProctorActions.ForceSubmitByProctor,
            OccurredAt = now,
            CreatedAt = now,
        });

        await _db.SaveChangesAsync();
        return Ok(new ApiResponse<object>(200, "Sesi ujian berhasil diselesaikan paksa.", new { sessionId = session.SessionId, responseId = response.Id }));
    }

    /// <summary>
    /// Reset/kick sesi peserta (izinkan ujian ulang): hapus sesi + log
    /// pelanggarannya (cascade) agar peserta dapat memulai sesi baru di /f/{formLink}.
    /// Spec B12 (route kanonis): POST /api/forms/{formId}/exam-monitoring/sessions/{sessionId}/reset.
    /// </summary>
    [HttpPost("api/forms/{formId}/exam-monitoring/sessions/{sessionId}/reset")]
    public Task<ActionResult<ApiResponse<object>>> ResetSessionSpec(int formId, string sessionId)
        => DoResetSession(formId, sessionId);

    /// <summary>Alias kompatibilitas route lama (mobile versi lama).</summary>
    [HttpDelete("api/forms/{formId}/exam/sessions/{sessionId}")]
    public Task<ActionResult<ApiResponse<object>>> ResetSession(int formId, string sessionId)
        => DoResetSession(formId, sessionId);

    private async Task<ActionResult<ApiResponse<object>>> DoResetSession(int formId, string sessionId)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.DeletedAt == null);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));
        if (form.UserId != user.Id && user.Role != "ADMIN")
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var session = await _db.ExamSessions
            .FirstOrDefaultAsync(s => s.FormId == formId && s.SessionId == sessionId);
        if (session == null)
            return NotFound(new ApiResponse<object>(404, "Session not found"));

        _db.ExamSessions.Remove(session);
        await _db.SaveChangesAsync();
        return Ok(new ApiResponse<object>(200, "Sesi peserta berhasil di-reset."));
    }

    /// <summary>
    /// Spec B12: simpan draft jawaban sementara/heartbeat agar data terakhir
    /// peserta tidak hilang (mati lampu / force-submit). Upsert Response
    /// status "new" + RespondentAnswers per questionId.
    /// </summary>
    [HttpPost("api/public/forms/{formLink}/exam-sessions/{sessionId}/sync-answers")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<object>>> SyncAnswers(
        string formLink, string sessionId, [FromBody] SyncAnswersRequest request)
    {
        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.FormLink == formLink && f.DeletedAt == null);
        if (form == null || form.TakenDownAt != null)
            return NotFound(new ApiResponse<object>(404, "Form tidak ditemukan"));

        if (string.IsNullOrWhiteSpace(sessionId))
            return BadRequest(new ApiResponse<object>(400, "SessionId wajib diisi"));

        var now = DateTime.UtcNow;
        var respondentId = ExamViolationTracker.ResolveRespondentId(User);
        var respondentName = ExamViolationTracker.ResolveRespondentName(User, request?.RespondentName);

        var session = await _db.ExamSessions
            .FirstOrDefaultAsync(s => s.FormId == form.Id && s.SessionId == sessionId);
        if (session == null)
        {
            session = new ExamSession
            {
                FormId = form.Id,
                SessionId = sessionId,
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
            if (session.SubmittedResponseId.HasValue)
                return BadRequest(new ApiResponse<object>(400, "Sesi sudah disubmit"));
            session.LastSeenAt = now;
            session.UpdatedAt = now;
            if (session.RespondentId == null) session.RespondentId = respondentId;
            if (string.IsNullOrWhiteSpace(session.RespondentName) && !string.IsNullOrWhiteSpace(respondentName))
                session.RespondentName = respondentName;
        }

        var items = request?.Answers ?? new List<SyncAnswerItem>();
        if (items.Count == 0)
        {
            await _db.SaveChangesAsync();
            return Ok(new ApiResponse<object>(200, "OK", new { sessionId = session.SessionId, saved = 0 }));
        }

        var questionIds = items.Select(a => a.QuestionId).Distinct().ToList();
        var validQuestionIds = await _db.Questions
            .Where(q => q.FormId == form.Id && q.DeletedAt == null && questionIds.Contains(q.Id))
            .Select(q => q.Id)
            .ToListAsync();
        if (validQuestionIds.Count == 0)
            return BadRequest(new ApiResponse<object>(400, "Tidak ada questionId valid untuk form ini"));

        var newStatus = await _db.ResponseStatuses.FirstOrDefaultAsync(s => s.Status == "new")
            ?? await _db.ResponseStatuses.FirstOrDefaultAsync();
        if (newStatus == null)
            return BadRequest(new ApiResponse<object>(400, "Status respons belum dikonfigurasi"));

        Response? draft = null;
        var draftQuery = _db.Responses
            .Include(r => r.RespondentAnswers)
            .Where(r => r.FormId == form.Id && r.StatusId == newStatus.Id);
        draft = session.RespondentId.HasValue
            ? await draftQuery.OrderByDescending(r => r.CreatedAt)
                .FirstOrDefaultAsync(r => r.RespondentId == session.RespondentId)
            : (!string.IsNullOrWhiteSpace(session.RespondentName)
                ? await draftQuery.OrderByDescending(r => r.CreatedAt)
                    .FirstOrDefaultAsync(r => r.RespondentId == null && r.RespondentName == session.RespondentName)
                : null);

        if (draft == null)
        {
            draft = new Response
            {
                FormId = form.Id,
                RespondentId = session.RespondentId,
                RespondentName = session.RespondentName,
                StatusId = newStatus.Id,
                CreatedAt = now,
                UpdatedAt = now,
            };
            _db.Responses.Add(draft);
            await _db.SaveChangesAsync();
        }

        var saved = 0;
        // Hapus dulu jawaban draft lama untuk soal-soal ini agar checkbox
        // (multi-baris per questionId) tidak menumpuk/ganda, lalu insert ulang.
        var stale = await _db.RespondentAnswers
            .Where(a => a.ResponseId == draft.Id && validQuestionIds.Contains(a.QuestionId))
            .ToListAsync();
        _db.RespondentAnswers.RemoveRange(stale);

        foreach (var item in items.Where(a => validQuestionIds.Contains(a.QuestionId)))
        {
            var answerValue = string.IsNullOrWhiteSpace(item.AnswerValue) ? null : item.AnswerValue.Trim();
            draft.RespondentAnswers.Add(new RespondentAnswer
            {
                ResponseId = draft.Id,
                QuestionId = item.QuestionId,
                AnswerValue = answerValue,
                OptionId = item.OptionId,
                CreatedAt = now,
                UpdatedAt = now,
            });
            saved++;
        }

        draft.UpdatedAt = now;
        session.LastSeenAt = now;
        session.UpdatedAt = now;
        await _db.SaveChangesAsync();
        return Ok(new ApiResponse<object>(200, "OK", new { sessionId = session.SessionId, saved }));
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }
}
