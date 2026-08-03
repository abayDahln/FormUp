using System.Security.Claims;
using FormUpAPI.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Services;

public static class ResponseSubmission
{
    public static async Task<ActionResult> SaveAsync(
        FormUpDbContext db, ClaimsPrincipal user,
        int formId, SubmitResponseRequest body)
    {
        var form = await db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == formId && f.DeletedAt == null);

        // Pesan generik supaya link yang tidak ada/tertutup tidak bisa dibedakan (anti link-guessing).
        if (form == null || form.TakenDownAt != null)
            return new NotFoundObjectResult(new ApiResponse<object>(404, "Form not found or unavailable"));

        var publishedStatus = await db.FormStatuses.FirstAsync(s => s.Status == "published");
        var closedStatus = await db.FormStatuses.FirstAsync(s => s.Status == "closed");

        if (form.StatusId != publishedStatus.Id && form.StatusId != closedStatus.Id)
            return new NotFoundObjectResult(new ApiResponse<object>(404, "Form not found or unavailable"));

        if (form.StatusId == closedStatus.Id)
            return new NotFoundObjectResult(new ApiResponse<object>(404, "Form not found or unavailable"));

        if (form.FormSetting?.CloseFormTime != null && form.FormSetting.CloseFormTime < JakartaTime.Now)
            return new NotFoundObjectResult(new ApiResponse<object>(404, "Form not found or unavailable"));

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

        var newStatus = await db.ResponseStatuses.FirstAsync(s => s.Status == "new");

        var response = new Response
        {
            FormId = formId,
            RespondentId = respondentId,
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
