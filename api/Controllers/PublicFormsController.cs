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
    public async Task<ActionResult<ApiResponse<object>>> GetForm(string formLink)
    {
        var form = await ResolveFormAsync(formLink);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found or unavailable"));

        var requiresToken = !string.IsNullOrEmpty(form.FormSetting?.FormToken);
        if (requiresToken && Request.Query["token"].ToString() != form.FormSetting!.FormToken)
            return Unauthorized(new ApiResponse<object>(401, "Invalid or missing form token"));

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions.OrderBy(o => o.OptionOrder))
            .Where(q => q.FormId == form.Id && q.DeletedAt == null)
            .OrderBy(q => q.QuestionOrder)
            .ToListAsync();

        return Ok(new ApiResponse<object>(200, "OK", new PublicFormDetails
        {
            Id = form.Id,
            Title = form.Title,
            Description = form.Description,
            BannerImage = form.BannerImage,
            RequiresToken = requiresToken,
            ShowScore = form.FormSetting?.ShowScore,
            TimerDuration = form.FormSetting?.TimerDuration,
            RandomizeQuestions = form.FormSetting?.RandomizeQuestions,
            Questions = questions.Select(MapPublicQuestion).ToList(),
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

        if (form.FormSetting?.CloseFormTime != null && form.FormSetting.CloseFormTime < JakartaTime.Now)
            return null;

        return form;
    }

    // ponytail: mapper publik, jangan bocorkan kunci
    private static QuestionResponse MapPublicQuestion(Question q) => new()
    {
        Id = q.Id,
        FormId = q.FormId,
        TypeId = q.TypeId,
        Question = q.Question1,
        QuestionOrder = q.QuestionOrder,
        QuestionImage = q.QuestionImage,
        QuestionAudio = q.QuestionAudio,
        IsRequired = q.IsRequired,
        CorrectAnswer = null,
        RandomizeOptions = q.RandomizeOptions,
        Options = (q.OptionQuestions ?? []).OrderBy(o => o.OptionOrder).Select(o => new OptionResponse
        {
            Id = o.Id,
            OptionText = o.OptionText ?? "",
            OptionImage = o.OptionImage,
            IsCorrect = null,
            OptionOrder = o.OptionOrder,
        }).ToList(),
    };
}
