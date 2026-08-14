using FormUpAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

[Route("api")]
[ApiController]
[EnableRateLimiting("creator")]
public class FeedbacksController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public FeedbacksController(FormUpDbContext db)
    {
        _db = db;
    }

    [HttpPost("forms/{formId}/feedback")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<object>>> SubmitFeedback(int formId, [FromBody] SubmitFeedbackRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            return BadRequest(new ApiResponse<object>(400, "Reason is required"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var publishedStatus = await _db.FormStatuses.FirstAsync(s => s.Status == "published");
        if (form.StatusId != publishedStatus.Id)
            return BadRequest(new ApiResponse<object>(400, "Can only submit feedback for published forms"));

        var hasCompleted = await _db.Responses
            .AnyAsync(r => r.FormId == formId && r.RespondentId == user.Id);
        if (!hasCompleted)
            return BadRequest(new ApiResponse<object>(400, "You can only submit feedback after completing the form"));

        var existing = await _db.Feedbacks
            .AnyAsync(f => f.FormId == formId && f.UserId == user.Id);
        if (existing)
            return BadRequest(new ApiResponse<object>(400, "You have already submitted feedback for this form"));

        var response = await _db.Responses
            .FirstOrDefaultAsync(r => r.FormId == formId && r.RespondentId == user.Id);

        var feedback = new Feedback
        {
            FormId = formId,
            UserId = user.Id,
            ResponseId = response?.Id,
            Reason = request.Reason,
            Description = request.Description,
            CreatedAt = JakartaTime.Now,
        };

        _db.Feedbacks.Add(feedback);
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(201, "Feedback submitted", new { feedbackId = feedback.Id }));
    }

    [HttpGet("forms/{formId}/feedback")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<object>>> GetMyFeedback(int formId)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var feedback = await _db.Feedbacks
            .Include(f => f.Form)
            .FirstOrDefaultAsync(f => f.FormId == formId && f.UserId == user.Id);

        if (feedback == null)
            return NotFound(new ApiResponse<object>(404, "No feedback found"));

        return Ok(new ApiResponse<object>(200, "OK", new FeedbackResponse
        {
            Id = feedback.Id,
            FormId = feedback.FormId,
            FormTitle = feedback.Form?.Title ?? "",
            UserId = feedback.UserId,
            UserName = user.Fullname,
            Reason = feedback.Reason,
            Description = feedback.Description,
            CreatedAt = feedback.CreatedAt ?? DateTime.MinValue,
        }));
    }

    [HttpGet("admin/feedback")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<object>>> GetAllFeedback(
        [FromQuery] int? page,
        [FromQuery] int? pageSize,
        [FromQuery] string? search,
        [FromQuery] int? formId,
        [FromQuery] DateTime? createdFrom,
        [FromQuery] DateTime? createdTo)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        if (user.Role != "ADMIN")
            return Forbid();

        var query = _db.Feedbacks.AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim();
            query = query.Where(f =>
                (f.User != null && f.User.Fullname != null && f.User.Fullname.Contains(s)) ||
                (f.User != null && f.User.Email != null && f.User.Email.Contains(s)) ||
                (f.Description != null && f.Description.Contains(s)));
        }

        if (formId.HasValue)
            query = query.Where(f => f.FormId == formId.Value);

        if (createdFrom.HasValue)
            query = query.Where(f => f.CreatedAt >= createdFrom.Value);
        if (createdTo.HasValue)
            query = query.Where(f => f.CreatedAt <= createdTo.Value);

        var projected = query
            .OrderByDescending(f => f.CreatedAt)
            .Select(f => new AdminFeedbackListItem
            {
                Id = f.Id,
                FormId = f.FormId,
                FormTitle = f.Form != null ? f.Form.Title : "",
                FormLink = f.Form != null ? f.Form.FormLink : "",
                UserId = f.UserId,
                UserName = f.User != null ? f.User.Fullname : "",
                UserEmail = f.User != null ? f.User.Email : "",
                Reason = f.Reason,
                Description = f.Description,
                CreatedAt = f.CreatedAt ?? DateTime.MinValue,
            });

        // ponytail: tanpa page/pageSize → perilaku lama (semua sekaligus),
        // agar klien lama (web) tidak berubah. Dengan param → respons berpaginasi.
        if (page.HasValue && pageSize.HasValue && pageSize > 0)
        {
            var total = await projected.CountAsync();
            var items = await projected
                .Skip((page.Value - 1) * pageSize.Value)
                .Take(pageSize.Value)
                .ToListAsync();

            return Ok(new ApiResponse<object>(200, "OK", new
            {
                items,
                total,
                page = page.Value,
                pageSize = pageSize.Value,
            }));
        }

        var all = await projected.ToListAsync();
        return Ok(new ApiResponse<object>(200, "OK", all));
    }

    [HttpDelete("admin/feedback/{id}")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<object>>> DismissFeedback(int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        if (user.Role != "ADMIN")
            return Forbid();

        var feedback = await _db.Feedbacks.FindAsync(id);
        if (feedback == null)
            return NotFound(new ApiResponse<object>(404, "Feedback not found"));

        _db.Feedbacks.Remove(feedback);
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Feedback dismissed"));
    }

    [HttpPost("admin/feedback/{id}/takedown")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<object>>> TakedownForm(int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        if (user.Role != "ADMIN")
            return Forbid();

        var feedback = await _db.Feedbacks
            .Include(f => f.Form)
            .FirstOrDefaultAsync(f => f.Id == id);

        if (feedback == null)
            return NotFound(new ApiResponse<object>(404, "Feedback not found"));

        if (feedback.Form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        if (feedback.Form.TakenDownAt != null)
            return BadRequest(new ApiResponse<object>(400, "Form is already taken down"));

        feedback.Form.TakenDownAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Form has been taken down"));
    }

    [HttpPost("admin/feedback/{id}/restore")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<object>>> RestoreForm(int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        if (user.Role != "ADMIN")
            return Forbid();

        var feedback = await _db.Feedbacks
            .Include(f => f.Form)
            .FirstOrDefaultAsync(f => f.Id == id);

        if (feedback == null)
            return NotFound(new ApiResponse<object>(404, "Feedback not found"));

        if (feedback.Form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        if (feedback.Form.TakenDownAt == null)
            return BadRequest(new ApiResponse<object>(400, "Form is not taken down"));

        feedback.Form.TakenDownAt = null;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Form has been restored"));
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }
}
