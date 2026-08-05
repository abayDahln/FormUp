using System.Security.Claims;
using FormUpAPI.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Services;

public enum FormAccess
{
    Ok,
    NotFound,
    NotOpen,
    Closed,
}

public static class ResponseSubmission
{
    // ponytail: pesan dibedakan agar klien tahu alasan — tidak ditemukan / belum dibuka / sudah ditutup
    public static ObjectResult Unavailable(FormAccess access, Form? form)
    {
        var (status, message, data) = access switch
        {
            FormAccess.NotOpen => (403, "Form belum dibuka", (object?)new { openFormTime = form?.FormSetting?.OpenFormTime }),
            FormAccess.Closed => (403, "Form sudah ditutup", new { closeFormTime = form?.FormSetting?.CloseFormTime }),
            _ => (404, "Form tidak ditemukan", null),
        };

        return new ObjectResult(new ApiResponse<object>(status, message, data)) { StatusCode = status };
    }

    public static async Task<ActionResult> SaveAsync(
        FormUpDbContext db, ClaimsPrincipal user,
        int formId, SubmitResponseRequest body)
    {
        var form = await db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == formId && f.DeletedAt == null);

        // Pesan dibedakan agar klien tahu alasan: tidak ditemukan / belum dibuka / sudah ditutup.
        if (form == null || form.TakenDownAt != null)
            return Unavailable(FormAccess.NotFound, form);

        var publishedStatus = await db.FormStatuses.FirstAsync(s => s.Status == "published");
        var closedStatus = await db.FormStatuses.FirstAsync(s => s.Status == "closed");

        if (form.StatusId == closedStatus.Id)
            return Unavailable(FormAccess.Closed, form);

        if (form.StatusId != publishedStatus.Id)
            return Unavailable(FormAccess.NotFound, form);

        if (form.FormSetting?.OpenFormTime != null && form.FormSetting.OpenFormTime > JakartaTime.Now)
            return Unavailable(FormAccess.NotOpen, form);

        if (form.FormSetting?.CloseFormTime != null && form.FormSetting.CloseFormTime < JakartaTime.Now)
            return Unavailable(FormAccess.Closed, form);

        if (form.FormSetting?.RequiredLogin == true && user.Identity?.IsAuthenticated != true)
            return new UnauthorizedObjectResult(new ApiResponse<object>(401, "Login required to access this form"));

        if (!string.IsNullOrEmpty(form.FormSetting?.FormToken))
        {
            if (string.IsNullOrEmpty(body.Token) || body.Token != form.FormSetting.FormToken)
                return new UnauthorizedObjectResult(new ApiResponse<object>(401, "Invalid or missing form token"));
        }

        if (form.FormSetting?.OneResponse == true)
        {
            var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            var alreadySubmitted = false;

            if (!string.IsNullOrEmpty(userIdClaim) && int.TryParse(userIdClaim, out var userId))
                alreadySubmitted = await db.Responses
                    .AnyAsync(r => r.FormId == formId && r.RespondentId == userId);

            if (alreadySubmitted)
                return new BadRequestObjectResult(new ApiResponse<object>(400, "You have already submitted a response"));
        }

        var questionIds = body.Answers.Select(a => a.QuestionId).ToList();
        var validQuestions = await db.Questions
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .Select(q => q.Id)
            .ToListAsync();

        var invalidIds = questionIds.Except(validQuestions).ToList();
        if (invalidIds.Count > 0)
            return new BadRequestObjectResult(new ApiResponse<object>(400, $"Invalid question IDs: {string.Join(", ", invalidIds)}"));

        int? respondentId = null;
        var userIdClaim2 = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(userIdClaim2) && int.TryParse(userIdClaim2, out var uid))
            respondentId = uid;

        // ponytail: nama tamu hanya untuk responden tanpa login; user login diidentifikasi lewat RespondentId
        var respondentName = respondentId == null ? body.RespondentName : null;

        var newStatus = await db.ResponseStatuses.FirstAsync(s => s.Status == "new");

        var response = new Response
        {
            FormId = formId,
            RespondentId = respondentId,
            RespondentName = respondentName,
            StatusId = newStatus.Id,
            SubmittedAt = JakartaTime.Now,
            CreatedAt = JakartaTime.Now,
        };

        db.Responses.Add(response);
        await db.SaveChangesAsync();

        var answers = body.Answers.Select(a => new RespondentAnswer
        {
            ResponseId = response.Id,
            QuestionId = a.QuestionId,
            OptionId = a.OptionId,
            AnswerValue = a.AnswerValue,
            CreatedAt = JakartaTime.Now,
        }).ToList();

        db.RespondentAnswers.AddRange(answers);
        await db.SaveChangesAsync();

        return new OkObjectResult(new ApiResponse<object>(201, "Response submitted", new { responseId = response.Id }));
    }
}
