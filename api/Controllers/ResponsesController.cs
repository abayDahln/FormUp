using System.Security.Claims;
using FormUpAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

[ApiController]
[Authorize]
public class ResponsesController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public ResponsesController(FormUpDbContext db)
    {
        _db = db;
    }

    [HttpPost("api/forms/{formId}/responses")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<object>>> Submit(int formId, [FromBody] SubmitResponseRequest request)
    {
        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == formId && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var publishedStatus = await _db.FormStatuses.FirstAsync(s => s.Status == "published");
        var closedStatus = await _db.FormStatuses.FirstAsync(s => s.Status == "closed");

        if (form.StatusId != publishedStatus.Id && form.StatusId != closedStatus.Id)
            return BadRequest(new ApiResponse<object>(400, "Form is not accepting responses"));

        if (form.StatusId == closedStatus.Id)
            return BadRequest(new ApiResponse<object>(400, "Form is closed"));

        if (form.FormSetting?.CloseFormTime != null && form.FormSetting.CloseFormTime < DateTime.UtcNow)
            return BadRequest(new ApiResponse<object>(400, "Form submission period has ended"));

        if (!string.IsNullOrEmpty(form.FormSetting?.FormToken))
        {
            if (string.IsNullOrEmpty(request.Token) || request.Token != form.FormSetting.FormToken)
                return Unauthorized(new ApiResponse<object>(401, "Invalid or missing form token"));
        }

        if (form.FormSetting?.OneResponse == true)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!string.IsNullOrEmpty(userIdClaim) && int.TryParse(userIdClaim, out var userId))
            {
                var existing = await _db.Responses
                    .AnyAsync(r => r.FormId == formId && r.RespondentId == userId);
                if (existing)
                    return BadRequest(new ApiResponse<object>(400, "You have already submitted a response"));
            }
        }

        var questionIds = request.Answers.Select(a => a.QuestionId).ToList();
        var validQuestions = await _db.Questions
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .Select(q => q.Id)
            .ToListAsync();

        var invalidIds = questionIds.Except(validQuestions).ToList();
        if (invalidIds.Count > 0)
            return BadRequest(new ApiResponse<object>(400, $"Invalid question IDs: {string.Join(", ", invalidIds)}"));

        int? respondentId = null;
        var userIdClaim2 = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(userIdClaim2) && int.TryParse(userIdClaim2, out var uid))
            respondentId = uid;

        var newStatus = await _db.ResponseStatuses.FirstAsync(s => s.Status == "new");

        var response = new Response
        {
            FormId = formId,
            RespondentId = respondentId,
            StatusId = newStatus.Id,
            SubmittedAt = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow,
        };

        _db.Responses.Add(response);
        await _db.SaveChangesAsync();

        var answers = request.Answers.Select(a => new RespondentAnswer
        {
            ResponseId = response.Id,
            QuestionId = a.QuestionId,
            OptionId = a.OptionId,
            AnswerValue = a.AnswerValue,
            CreatedAt = DateTime.UtcNow,
        }).ToList();

        _db.RespondentAnswers.AddRange(answers);
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(201, "Response submitted", new { responseId = response.Id }));
    }

    [HttpGet("api/forms/{formId}/responses")]
    public async Task<ActionResult<ApiResponse<object>>> GetAll(int formId)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var responses = await _db.Responses
            .Include(r => r.Status)
            .Include(r => r.Respondent)
            .Where(r => r.FormId == formId)
            .OrderByDescending(r => r.SubmittedAt)
            .Select(r => new ResponseListItem
            {
                Id = r.Id,
                RespondentName = r.Respondent != null ? r.Respondent.Fullname : null,
                Status = r.Status!.Status,
                SubmittedAt = r.SubmittedAt ?? r.CreatedAt ?? DateTime.UtcNow,
            })
            .ToListAsync();

        return Ok(new ApiResponse<object>(200, "OK", responses));
    }

    [HttpGet("api/forms/{formId}/responses/{id}")]
    public async Task<ActionResult<ApiResponse<object>>> GetById(int formId, int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var response = await _db.Responses
            .Include(r => r.Status)
            .Include(r => r.Respondent)
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Question)
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Option)
            .FirstOrDefaultAsync(r => r.Id == id && r.FormId == formId);

        if (response == null)
            return NotFound(new ApiResponse<object>(404, "Response not found"));

        var detail = new ResponseDetail
        {
            Id = response.Id,
            FormId = response.FormId,
            RespondentName = response.Respondent?.Fullname,
            Status = response.Status?.Status ?? "unknown",
            SubmittedAt = response.SubmittedAt ?? response.CreatedAt ?? DateTime.UtcNow,
            Answers = response.RespondentAnswers.Select(a => new AnswerDetail
            {
                QuestionId = a.QuestionId,
                Question = a.Question?.Question1 ?? "",
                TypeId = a.Question?.TypeId ?? 0,
                OptionId = a.OptionId,
                OptionText = a.Option?.OptionText,
                AnswerValue = a.AnswerValue,
            }).ToList(),
        };

        return Ok(new ApiResponse<object>(200, "OK", detail));
    }

    [HttpPut("api/responses/{id}/status")]
    public async Task<ActionResult<ApiResponse<object>>> UpdateStatus(int id, [FromBody] UpdateResponseStatusRequest request)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var response = await _db.Responses
            .Include(r => r.Form)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (response == null)
            return NotFound(new ApiResponse<object>(404, "Response not found"));

        if (response.Form == null || response.Form.UserId != user.Id)
            return Forbid();

        var statusExists = await _db.ResponseStatuses.AnyAsync(s => s.Id == request.StatusId);
        if (!statusExists)
            return BadRequest(new ApiResponse<object>(400, "Invalid status ID"));

        response.StatusId = request.StatusId;
        response.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Status updated"));
    }

    [HttpGet("api/forms/{formId}/responses/export")]
    public async Task<IActionResult> Export(int formId)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var questions = await _db.Questions
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .OrderBy(q => q.QuestionOrder)
            .ToListAsync();

        var responses = await _db.Responses
            .Include(r => r.Respondent)
            .Include(r => r.Status)
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Option)
            .Where(r => r.FormId == formId)
            .OrderByDescending(r => r.SubmittedAt)
            .ToListAsync();

        using var writer = new System.IO.StringWriter();

        writer.Write("Response ID,Submitted At,Respondent");
        foreach (var q in questions)
            writer.Write($",{EscapeCsv(q.Question1)}");
        writer.WriteLine(",Status");

        foreach (var r in responses)
        {
            writer.Write($"{r.Id},{r.SubmittedAt:yyyy-MM-dd HH:mm:ss},{EscapeCsv(r.Respondent?.Fullname ?? "Anonymous")}");

            foreach (var q in questions)
            {
                var answer = r.RespondentAnswers.FirstOrDefault(a => a.QuestionId == q.Id);
                if (answer == null)
                {
                    writer.Write(",");
                }
                else if (answer.OptionId.HasValue)
                {
                    writer.Write($",{EscapeCsv(answer.Option?.OptionText ?? "")}");
                }
                else
                {
                    writer.Write($",{EscapeCsv(answer.AnswerValue ?? "")}");
                }
            }

            writer.WriteLine($",{r.Status?.Status ?? "unknown"}");
        }

        var csvBytes = System.Text.Encoding.UTF8.GetBytes(writer.ToString());
        return File(csvBytes, "text/csv", $"responses-form-{formId}.csv");
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }

    private static string EscapeCsv(string? value)
    {
        if (string.IsNullOrEmpty(value)) return "";
        if (value.Contains(',') || value.Contains('"') || value.Contains('\n') || value.Contains('\r'))
            return $"\"{value.Replace("\"", "\"\"")}\"";
        return value;
    }
}
