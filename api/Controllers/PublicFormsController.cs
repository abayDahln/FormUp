using System.Security.Claims;
using FormUpAPI.Models;
using FormUpAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

[Route("api/public")]
[ApiController]
public class PublicFormsController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public PublicFormsController(FormUpDbContext db)
    {
        _db = db;
    }

    [HttpGet("forms/{formLink}")]
    [AllowAnonymous]
    [EnableRateLimiting("submit")]
    public async Task<ActionResult<ApiResponse<object>>> GetForm(string formLink)
    {
        var form = await ResolveFormAsync(formLink);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form tidak ditemukan"));

        var isOwner = User.Identity?.IsAuthenticated == true
            && int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var uid)
            && form.UserId == uid;

        var questionCount = await _db.Questions
            .CountAsync(q => q.FormId == form.Id && q.DeletedAt == null);

        return Ok(new ApiResponse<object>(200, "OK", new PublicFormDetails
        {
            Id = form.Id,
            Title = form.Title,
            Description = form.Description,
            DescriptionFormat = form.DescriptionFormat ?? RichTextValidation.FormatOf(form.Description),
            BannerImage = form.BannerImage,
            RequiresToken = !string.IsNullOrEmpty(form.FormSetting?.FormToken),
            RequiresLogin = form.FormSetting?.RequiredLogin == true,
            OneResponse = form.FormSetting?.OneResponse == true,
            IsOwner = isOwner,
            FormTypeId = form.FormSetting?.FormTypeId,
            ShowScore = form.FormSetting?.ShowScore,
            TimerDuration = form.FormSetting?.TimerDuration,
            RandomizeQuestions = form.FormSetting?.RandomizeQuestions,
            OpenFormTime = form.FormSetting?.OpenFormTime,
            CloseFormTime = form.FormSetting?.CloseFormTime,
            QuestionCount = questionCount,
        }));
    }

    [HttpPost("forms/{formLink}/questions")]
    [AllowAnonymous]
    [EnableRateLimiting("submit")]
    public async Task<ActionResult<ApiResponse<object>>> GetQuestions(string formLink, [FromBody] PublicQuestionsRequest request)
    {
        var form = await ResolveFormAsync(formLink);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form tidak ditemukan"));

        var accessError = CheckAccess(form, request.Token);
        if (accessError != null)
            return accessError;

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions.OrderBy(o => o.OptionOrder))
            .Where(q => q.FormId == form.Id && q.DeletedAt == null)
            .ToListAsync();

        if (form.FormSetting?.RandomizeQuestions == true)
            Shuffle(questions);
        else
            questions = questions.OrderBy(q => q.QuestionOrder).ToList();

        return Ok(new ApiResponse<object>(200, "OK", new PublicQuestionsResponse
        {
            FormId = form.Id,
            Questions = questions
                .Select(q => MapPublicQuestion(q, randomizeOptions: q.RandomizeOptions == true))
                .ToList(),
        }));
    }

    [HttpPost("forms/{formLink}/responses")]
    [AllowAnonymous]
    [EnableRateLimiting("submit")]
    public async Task<ActionResult<ApiResponse<object>>> Submit(string formLink, [FromBody] SubmitResponseRequest request)
    {
        var form = await ResolveFormAsync(formLink);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found or unavailable"));

        return await ResponseSubmission.SaveAsync(_db, User, form.Id, request);
    }

    [HttpGet("forms/{formLink}/responses/{responseId}")]
    [AllowAnonymous]
    [EnableRateLimiting("submit")]
    public async Task<ActionResult<ApiResponse<object>>> GetResult(string formLink, int responseId)
    {
        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.FormLink == formLink && f.DeletedAt == null);

        if (form == null || form.TakenDownAt != null)
            return NotFound(new ApiResponse<object>(404, "Form tidak ditemukan"));

        var response = await _db.Responses
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Option)
            .FirstOrDefaultAsync(r => r.Id == responseId && r.FormId == form.Id);

        if (response == null)
            return NotFound(new ApiResponse<object>(404, "Response tidak ditemukan"));

        var isOwner = User.Identity?.IsAuthenticated == true
            && int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var uid)
            && response.RespondentId == uid;

        // Respons guest (tanpa akun) tidak memiliki identitas — bisa diakses
        // siapa pun yang menyimpan link + responseId setelah submit.
        // Respons milik user login tetap hanya bisa dibaca pemiliknya.
        if (!isOwner && response.RespondentId != null)
            return Unauthorized(new ApiResponse<object>(401, "Anda tidak berhak melihat hasil ini"));

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions)
            .Where(q => q.FormId == form.Id && q.DeletedAt == null)
            .ToListAsync();

        return Ok(new ApiResponse<object>(200, "OK", ResponseScorer.BuildResult(form, response, questions)));
    }

    [HttpGet("forms/{formLink}/my-responses")]
    [Authorize]
    [EnableRateLimiting("submit")]
    public async Task<ActionResult<ApiResponse<object>>> GetMyResponses(string formLink)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.FormLink == formLink && f.DeletedAt == null);

        if (form == null || form.TakenDownAt != null)
            return NotFound(new ApiResponse<object>(404, "Form tidak ditemukan"));

        var responses = await _db.Responses
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Option)
            .Where(r => r.FormId == form.Id && r.RespondentId == userId)
            .OrderByDescending(r => r.SubmittedAt)
            .ToListAsync();

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions)
            .Where(q => q.FormId == form.Id && q.DeletedAt == null)
            .ToListAsync();

        var attempts = responses.Select(r =>
        {
            var built = ResponseScorer.BuildResult(form, r, questions);
            return new MyAttemptDto
            {
                ResponseId = r.Id,
                SubmittedAt = r.SubmittedAt,
                ShowScore = built.ShowScore,
                Score = built.Score,
                CorrectCount = built.CorrectCount,
                WrongCount = built.WrongCount,
            };
        }).ToList();

        return Ok(new ApiResponse<object>(200, "OK", attempts));
    }

    private ActionResult? CheckAccess(Form form, string? token)
    {
        if (User.Identity?.IsAuthenticated == true
            && int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var uid)
            && form.UserId == uid)
            return BadRequest(new ApiResponse<object>(400, "Anda tidak dapat mengisi form yang Anda buat sendiri"));

        if (form.FormSetting?.RequiredLogin == true && User.Identity?.IsAuthenticated != true)
            return Unauthorized(new ApiResponse<object>(401, "Login required to access this form"));

        if (!string.IsNullOrEmpty(form.FormSetting?.FormToken))
        {
            if (string.IsNullOrEmpty(token) || token != form.FormSetting.FormToken)
                return Unauthorized(new ApiResponse<object>(401, "Invalid or missing form token"));
        }

        return null;
    }

    private async Task<Form?> ResolveFormAsync(string formLink)
    {
        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.FormLink == formLink && f.DeletedAt == null);

        if (form == null || form.TakenDownAt != null)
            return null;

        var publishedStatus = await _db.FormStatuses.FirstAsync(s => s.Status == "published");
        if (form.StatusId != publishedStatus.Id)
            return null;

        if (form.FormSetting?.OpenFormTime != null && form.FormSetting.OpenFormTime > JakartaTime.Now)
            return null;

        if (form.FormSetting?.CloseFormTime != null && form.FormSetting.CloseFormTime < JakartaTime.Now)
            return null;

        return form;
    }

    private static QuestionResponse MapPublicQuestion(Question q, bool randomizeOptions = false)
    {
        var options = (q.OptionQuestions ?? []).OrderBy(o => o.OptionOrder).ToList();
        if (randomizeOptions)
            Shuffle(options);

        return new QuestionResponse
        {
            Id = q.Id,
            FormId = q.FormId,
            TypeId = q.TypeId,
            Question = q.Question1,
            QuestionFormat = q.QuestionFormat ?? RichTextValidation.FormatOf(q.Question1),
            QuestionOrder = q.QuestionOrder,
            QuestionImage = q.QuestionImage,
            QuestionAudio = q.QuestionAudio,
            IsRequired = q.IsRequired,
            CorrectAnswer = null,
            RandomizeOptions = q.RandomizeOptions,
            Options = options.Select(o => new OptionResponse
            {
                Id = o.Id,
                OptionText = o.OptionText ?? "",
                OptionImage = o.OptionImage,
                IsCorrect = null,
                OptionOrder = o.OptionOrder,
            }).ToList(),
        };
    }

    private static void Shuffle<T>(IList<T> list)
    {
        for (var i = list.Count - 1; i > 0; i--)
        {
            var j = Random.Shared.Next(i + 1);
            (list[i], list[j]) = (list[j], list[i]);
        }
    }
}
