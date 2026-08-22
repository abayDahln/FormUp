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
        // Transaksi serializable + UPDLOCK pada row form: menyerialisasi
        // submit respons terhadap pembuat form yang sedang mengedit/menghapus
        // soal di waktu bersamaan.
        await using var tx = await db.Database.BeginTransactionAsync(
            System.Data.IsolationLevel.Serializable);

        await db.Database.ExecuteSqlRawAsync(
            "SELECT [id] FROM [Form] WITH (UPDLOCK, ROWLOCK) WHERE [id] = {0}", formId);

        var form = await db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == formId && f.DeletedAt == null);

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

        var isAuthenticated = user.Identity?.IsAuthenticated == true;

        if (form.FormSetting?.RequiredLogin == true && !isAuthenticated)
            return new UnauthorizedObjectResult(new ApiResponse<object>(401, "Login required to access this form"));

        if (!string.IsNullOrEmpty(form.FormSetting?.FormToken))
        {
            if (string.IsNullOrEmpty(body.Token) || body.Token != form.FormSetting.FormToken)
                return new UnauthorizedObjectResult(new ApiResponse<object>(401, "Invalid or missing form token"));
        }

        var ownerClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(ownerClaim) && int.TryParse(ownerClaim, out var ownerUid) && form.UserId == ownerUid)
            return new BadRequestObjectResult(new ApiResponse<object>(400, "Anda tidak dapat mengisi form yang Anda buat sendiri"));

        if (form.FormSetting?.OneResponse == true)
        {
            var alreadySubmitted = false;

            if (isAuthenticated)
            {
                var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
                if (!string.IsNullOrEmpty(userIdClaim) && int.TryParse(userIdClaim, out var userId))
                    alreadySubmitted = await db.Responses
                        .AnyAsync(r => r.FormId == formId && r.RespondentId == userId);
            }

            if (alreadySubmitted)
                return new BadRequestObjectResult(new ApiResponse<object>(400, "You have already submitted a response"));
        }

        var questionIds = body.Answers.Select(a => a.QuestionId).ToList();
        var validQuestions = await db.Questions
            .Include(q => q.OptionQuestions)
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .ToListAsync();

        var invalidIds = questionIds.Except(validQuestions.Select(q => q.Id)).ToList();
        if (invalidIds.Count > 0)
            return new BadRequestObjectResult(new ApiResponse<object>(400, $"Invalid question IDs: {string.Join(", ", invalidIds)}"));

        var answersByQuestion = body.Answers
            .Where(a => validQuestions.Any(q => q.Id == a.QuestionId))
            .GroupBy(a => a.QuestionId)
            .ToDictionary(g => g.Key, g => g.ToList());

        foreach (var q in validQuestions.Where(q => q.IsRequired == true))
        {
            if (!answersByQuestion.TryGetValue(q.Id, out var answerList))
                return new BadRequestObjectResult(new ApiResponse<object>(400, $"Pertanyaan \"{q.Question1}\" wajib dijawab"));

            var answered = q.TypeId switch
            {
                2 or 3 => answerList.Any(a => a.OptionId.HasValue),
                _ => answerList.Any(a => a.AnswerValue is { Length: > 0 } && !string.IsNullOrWhiteSpace(a.AnswerValue)),
            };
            if (!answered)
                return new BadRequestObjectResult(new ApiResponse<object>(400, $"Pertanyaan \"{q.Question1}\" wajib dijawab"));
        }

        foreach (var (questionId, ansList) in answersByQuestion)
        {
            var q = validQuestions.First(x => x.Id == questionId);

            switch (q.TypeId)
            {
                case 2:
                    if (ansList.Count != 1 ||
                        ansList[0].OptionId is not int optId2 ||
                        ansList[0].AnswerValue != null ||
                        !q.OptionQuestions.Any(o => o.Id == optId2))
                        return new BadRequestObjectResult(new ApiResponse<object>(400, "Jawaban pilihan ganda tidak valid"));
                    break;

                case 3:
                    if (ansList.Any(a => a.AnswerValue != null || a.OptionId is not int oid ||
                        !q.OptionQuestions.Any(o => o.Id == oid)))
                        return new BadRequestObjectResult(new ApiResponse<object>(400, "Jawaban checkbox tidak valid"));
                    break;

                case 5:
                    if (ansList.Count != 1 ||
                        ansList[0].OptionId.HasValue ||
                        ansList[0].AnswerValue is not ("Benar" or "Salah"))
                        return new BadRequestObjectResult(new ApiResponse<object>(400, "Jawaban benar/salah tidak valid"));
                    break;

                case 1:
                case 4:
                    if (ansList.Count > 1 || ansList.Any(a => a.OptionId.HasValue))
                        return new BadRequestObjectResult(new ApiResponse<object>(400, "Jawaban tidak valid untuk tipe soal ini"));
                    break;
            }
        }

        int? respondentId = null;
        var userIdClaim2 = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(userIdClaim2) && int.TryParse(userIdClaim2, out var uid))
            respondentId = uid;

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

        tx.Commit();

        return new OkObjectResult(new ApiResponse<object>(201, "Response submitted", new { responseId = response.Id }));
    }
}
