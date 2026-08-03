using System.Security.Claims;
using FormUpAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

[Route("api/admin")]
[ApiController]
[EnableRateLimiting("creator")]
[Authorize]
public class AdminController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public AdminController(FormUpDbContext db)
    {
        _db = db;
    }

    [HttpGet("users")]
    public async Task<ActionResult<ApiResponse<object>>> GetAllUsers()
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var users = await _db.Users
            .OrderByDescending(u => u.CreatedAt)
            .Select(u => new AdminUserListItem
            {
                Id = u.Id,
                Fullname = u.Fullname,
                Username = u.Username,
                Email = u.Email,
                Role = u.Role ?? "USER",
                IsActive = u.IsActive,
                FormCount = u.Forms.Count(f => f.DeletedAt == null),
                CreatedAt = u.CreatedAt,
                DeletedAt = u.DeletedAt,
            })
            .ToListAsync();

        return Ok(new ApiResponse<object>(200, "OK", users));
    }

    [HttpGet("users/{id}")]
    public async Task<ActionResult<ApiResponse<object>>> GetUserDetail(int id)
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var user = await _db.Users
            .Include(u => u.Forms)
            .Include(u => u.Responses)
            .FirstOrDefaultAsync(u => u.Id == id);

        if (user == null)
            return NotFound(new ApiResponse<object>(404, "User not found"));

        return Ok(new ApiResponse<object>(200, "OK", new AdminUserDetailResponse
        {
            Id = user.Id,
            Fullname = user.Fullname,
            Username = user.Username,
            Email = user.Email,
            Role = user.Role,
            ProfileImage = user.ProfileImage,
            Birthdate = user.Birthdate?.ToString("yyyy-MM-dd"),
            IsActive = user.IsActive,
            FormCount = user.Forms.Count(f => f.DeletedAt == null),
            ResponseCount = user.Responses.Count,
            CreatedAt = user.CreatedAt,
            UpdatedAt = user.UpdatedAt,
            DeletedAt = user.DeletedAt,
        }));
    }

    [HttpPut("users/{id}/ban")]
    public async Task<ActionResult<ApiResponse<object>>> BanUser(int id)
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var user = await _db.Users.FindAsync(id);
        if (user == null)
            return NotFound(new ApiResponse<object>(404, "User not found"));

        if (user.Role == "ADMIN")
            return BadRequest(new ApiResponse<object>(400, "Cannot ban an admin"));

        user.IsActive = false;
        user.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "User has been banned"));
    }

    [HttpPut("users/{id}/activate")]
    public async Task<ActionResult<ApiResponse<object>>> ActivateUser(int id)
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var user = await _db.Users.FindAsync(id);
        if (user == null)
            return NotFound(new ApiResponse<object>(404, "User not found"));

        user.IsActive = true;
        user.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "User has been activated"));
    }    [HttpDelete("users/{id}")]
    public async Task<ActionResult<ApiResponse<object>>> SoftDeleteUser(int id)
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var user = await _db.Users.FindAsync(id);
        if (user == null)
            return NotFound(new ApiResponse<object>(404, "User not found"));

        if (user.Role == "ADMIN")
            return BadRequest(new ApiResponse<object>(400, "Cannot delete an admin"));

        user.DeletedAt = JakartaTime.Now;
        user.IsActive = false;
        user.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "User deleted"));
    }

    [HttpGet("forms")]
    public async Task<ActionResult<ApiResponse<object>>> GetAllForms()
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var forms = await _db.Forms
            .Include(f => f.Status)
            .Include(f => f.User)
            .OrderByDescending(f => f.CreatedAt)
            .Select(f => new AdminFormListItem
            {
                Id = f.Id,
                Title = f.Title,
                Description = f.Description,
                FormLink = f.FormLink,
                Status = f.Status != null ? f.Status.Status : "unknown",
                OwnerName = f.User != null ? f.User.Fullname : "",
                OwnerEmail = f.User != null ? f.User.Email : "",
                ResponseCount = f.Responses.Count,
                TakenDownAt = f.TakenDownAt,
                CreatedAt = f.CreatedAt,
                UpdatedAt = f.UpdatedAt,
                DeletedAt = f.DeletedAt,
            })
            .ToListAsync();

        return Ok(new ApiResponse<object>(200, "OK", forms));
    }

    [HttpGet("forms/{id}")]
    public async Task<ActionResult<ApiResponse<object>>> GetFormDetail(int id)
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var form = await _db.Forms
            .Include(f => f.Status)
            .Include(f => f.User)
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == id);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        return Ok(new ApiResponse<object>(200, "OK", new
        {
            id = form.Id,
            title = form.Title,
            description = form.Description,
            bannerImage = form.BannerImage,
            formLink = form.FormLink,
            status = form.Status?.Status ?? "unknown",
            owner = new
            {
                id = form.User?.Id,
                fullname = form.User?.Fullname,
                email = form.User?.Email,
            },
            takenDownAt = form.TakenDownAt,
            responseCount = await _db.Responses.CountAsync(r => r.FormId == form.Id),
            settings = form.FormSetting == null ? null : new FormSettingDto
            {
                FormTypeId = form.FormSetting.FormTypeId,
                ShowScore = form.FormSetting.ShowScore,
                RandomizeQuestions = form.FormSetting.RandomizeQuestions,
                TimerDuration = form.FormSetting.TimerDuration,
                OneResponse = form.FormSetting.OneResponse,
                CloseFormTime = form.FormSetting.CloseFormTime,
            },
            createdAt = form.CreatedAt,
            updatedAt = form.UpdatedAt,
            deletedAt = form.DeletedAt,
        }));
    }

    [HttpPost("forms/{id}/takedown")]
    public async Task<ActionResult<ApiResponse<object>>> TakedownForm(int id)
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var form = await _db.Forms.FindAsync(id);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        if (form.TakenDownAt != null)
            return BadRequest(new ApiResponse<object>(400, "Form is already taken down"));

        form.TakenDownAt = JakartaTime.Now;
        form.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Form has been taken down"));
    }

    [HttpPost("forms/{id}/restore")]
    public async Task<ActionResult<ApiResponse<object>>> RestoreForm(int id)
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var form = await _db.Forms.FindAsync(id);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        if (form.TakenDownAt == null)
            return BadRequest(new ApiResponse<object>(400, "Form is not taken down"));

        form.TakenDownAt = null;
        form.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Form has been restored"));
    }

    [HttpDelete("forms/{id}")]
    public async Task<ActionResult<ApiResponse<object>>> DeleteForm(int id)
    {
        var admin = await GetCurrentUser();
        if (admin == null || admin.Role != "ADMIN")
            return Forbid();

        var form = await _db.Forms.FindAsync(id);
        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        form.DeletedAt = JakartaTime.Now;
        form.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Form deleted"));
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }
}
