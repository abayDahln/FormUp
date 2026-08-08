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
            return NotFound(new ApiResponse<object>(404, "Form not found or unavailable"));

        // ponytail: tanpa soal di sini — soal hanya lewat /questions setelah requirement terpenuhi
        var isOwner = User.Identity?.IsAuthenticated == true
            && int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var uid)
            && form.UserId == uid;

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
        }));
    }

    [HttpPost("forms/{formLink}/questions")]
    [AllowAnonymous]
    [EnableRateLimiting("submit")]
    public async Task<ActionResult<ApiResponse<object>>> GetQuestions(string formLink, [FromBody] PublicQuestionsRequest request)
    {
        var form = await ResolveFormAsync(formLink);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found or unavailable"));

        var accessError = CheckAccess(form, request.Token);
        if (accessError != null)
            return accessError;

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions.OrderBy(o => o.OptionOrder))
            .Where(q => q.FormId == form.Id && q.DeletedAt == null)
            .ToListAsync();

        // ponytail: acak urutan soal hanya untuk responden — pembuat form tetap
        // melihat urutan asli lewat endpoint owner. Nomor soal (1,2,3,..) dibuat
        // client dari index, jadi otomatis tetap berurutan.
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

    // Hasil untuk responden: hanya pemilik respons (user login lewat JWT) yang
    // bisa melihat hasilnya. Tanpa login, hasil tidak tersedia.
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

        if (!isOwner)
            return Unauthorized(new ApiResponse<object>(401, "Anda tidak berhak melihat hasil ini"));

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions)
            .Where(q => q.FormId == form.Id && q.DeletedAt == null)
            .ToListAsync();

        return Ok(new ApiResponse<object>(200, "OK", ResponseScorer.BuildResult(form, response, questions)));
    }

    private ActionResult? CheckAccess(Form form, string? token)
    {
        // Pemilik form tidak boleh mengisi form sendiri.
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

    // ponytail: mapper publik, jangan bocorkan kunci
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

    /// <summary>Fisher-Yates shuffle in-place — dipakai untuk mengacak urutan
    /// soal/opsi per responden. Urutan ID tidak berubah, hanya posisinya.</summary>
    private static void Shuffle<T>(IList<T> list)
    {
        for (var i = list.Count - 1; i > 0; i--)
        {
            var j = Random.Shared.Next(i + 1);
            (list[i], list[j]) = (list[j], list[i]);
        }
    }
}
