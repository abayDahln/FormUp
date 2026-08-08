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

        var isAuthenticated = user.Identity?.IsAuthenticated == true;

        if (form.FormSetting?.RequiredLogin == true && !isAuthenticated)
            return new UnauthorizedObjectResult(new ApiResponse<object>(401, "Login required to access this form"));

        if (!string.IsNullOrEmpty(form.FormSetting?.FormToken))
        {
            if (string.IsNullOrEmpty(body.Token) || body.Token != form.FormSetting.FormToken)
                return new UnauthorizedObjectResult(new ApiResponse<object>(401, "Invalid or missing form token"));
        }

        // Pemilik form tidak boleh mengisi form sendiri.
        var ownerClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(ownerClaim) && int.TryParse(ownerClaim, out var ownerUid) && form.UserId == ownerUid)
            return new BadRequestObjectResult(new ApiResponse<object>(400, "Anda tidak dapat mengisi form yang Anda buat sendiri"));

        if (form.FormSetting?.OneResponse == true)
        {
            // ponytail: satu respons per orang hanya bisa dijamin untuk user login
            // (RespondentId). Tamu tanpa akun tidak bisa diidentifikasi secara
            // andal, jadi batasan ini tidak dipaksakan untuk guest.
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

        // ponytail: soal wajib (isRequired) harus benar-benar dijawab — jangan
        // percaya validasi di client saja, responden bisa kirim payload kosong.
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

        // ponytail: validasi isi jawaban per tipe soal — optionId harus milik
        // soal itu, dan tipe jawaban tidak boleh ditukar (mis. essay diisi option).
        foreach (var (questionId, ansList) in answersByQuestion)
        {
            var q = validQuestions.First(x => x.Id == questionId);

            switch (q.TypeId)
            {
                case 2: // Pilihan Ganda: tepat satu optionId milik soal, tanpa answerValue.
                    if (ansList.Count != 1 ||
                        ansList[0].OptionId is not int optId2 ||
                        ansList[0].AnswerValue != null ||
                        !q.OptionQuestions.Any(o => o.Id == optId2))
                        return new BadRequestObjectResult(new ApiResponse<object>(400, "Jawaban pilihan ganda tidak valid"));
                    break;

                case 3: // Checkbox: semua optionId milik soal, tanpa answerValue.
                    if (ansList.Any(a => a.AnswerValue != null || a.OptionId is not int oid ||
                        !q.OptionQuestions.Any(o => o.Id == oid)))
                        return new BadRequestObjectResult(new ApiResponse<object>(400, "Jawaban checkbox tidak valid"));
                    break;

                case 5: // Benar/Salah: tepat satu answerValue "Benar" atau "Salah".
                    if (ansList.Count != 1 ||
                        ansList[0].OptionId.HasValue ||
                        ansList[0].AnswerValue is not ("Benar" or "Salah"))
                        return new BadRequestObjectResult(new ApiResponse<object>(400, "Jawaban benar/salah tidak valid"));
                    break;

                case 1: // Essay.
                case 4: // Tanggal & Waktu.
                    if (ansList.Count > 1 || ansList.Any(a => a.OptionId.HasValue))
                        return new BadRequestObjectResult(new ApiResponse<object>(400, "Jawaban tidak valid untuk tipe soal ini"));
                    break;
            }
        }

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
