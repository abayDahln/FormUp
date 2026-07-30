using System.Security.Claims;
using FormUpAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public UsersController(FormUpDbContext db)
    {
        _db = db;
    }

    [HttpGet("me")]
    public async Task<ActionResult<ApiResponse<object>>> GetProfile()
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        return Ok(new ApiResponse<object>(200, "OK", MapUserDto(user)));
    }

    [HttpPut("me")]
    public async Task<ActionResult<ApiResponse<object>>> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        if (!string.IsNullOrWhiteSpace(request.Fullname))
        {
            if (request.Fullname.Length < 1)
                return BadRequest(new ApiResponse<object>(400, "Fullname cannot be empty"));
            user.Fullname = request.Fullname;
        }

        if (!string.IsNullOrWhiteSpace(request.Username))
        {
            if (request.Username.Length < 3)
                return BadRequest(new ApiResponse<object>(400, "Username must be at least 3 characters"));

            if (request.Username != user.Username && await _db.Users.AnyAsync(u => u.Username == request.Username))
                return Conflict(new ApiResponse<object>(409, "Username already taken"));

            user.Username = request.Username;
        }

        if (request.Birthdate != null)
        {
            if (!DateOnly.TryParse(request.Birthdate, out var birthdate))
                return BadRequest(new ApiResponse<object>(400, "Invalid birthdate format (use yyyy-MM-dd)"));
            user.Birthdate = birthdate;
        }

        user.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Profile updated", MapUserDto(user)));
    }

    [HttpPost("change-password")]
    public async Task<ActionResult<ApiResponse<object>>> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.CurrentPassword) || string.IsNullOrWhiteSpace(request.NewPassword))
            return BadRequest(new ApiResponse<object>(400, "Current password and new password are required"));

        if (request.NewPassword.Length < 8)
            return BadRequest(new ApiResponse<object>(400, "New password must be at least 8 characters"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        if (!PasswordHelper.Verify(request.CurrentPassword, user.Password))
            return BadRequest(new ApiResponse<object>(400, "Current password is incorrect"));

        user.Password = PasswordHelper.Hash(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Password changed successfully"));
    }

    [HttpPost("me/profile-image")]
    public async Task<ActionResult<ApiResponse<object>>> UploadProfileImage(IFormFile? file)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new ApiResponse<object>(400, "No file uploaded"));

        var allowedExts = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowedTypes = new[] { "image/jpeg", "image/png", "image/gif", "image/webp" };

        if (!allowedExts.Contains(ext))
            return BadRequest(new ApiResponse<object>(400, "Only JPG, PNG, GIF, and WebP files are allowed"));

        if (!allowedTypes.Contains(file.ContentType))
            return BadRequest(new ApiResponse<object>(400, "Invalid file type"));

        if (file.Length > 10 * 1024 * 1024)
            return BadRequest(new ApiResponse<object>(400, "File size must be under 10 MB"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var uniqueName = $"{Guid.NewGuid()}{ext}";
        var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "profile");
        Directory.CreateDirectory(uploadDir);
        var filePath = Path.Combine(uploadDir, uniqueName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        if (!string.IsNullOrEmpty(user.ProfileImage))
        {
            var oldPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", user.ProfileImage.TrimStart('/'));
            if (System.IO.File.Exists(oldPath))
                System.IO.File.Delete(oldPath);
        }

        user.ProfileImage = $"/profile/{uniqueName}";
        user.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Profile image uploaded", new { profileImage = user.ProfileImage }));
    }

    [HttpGet("me/stats")]
    public async Task<ActionResult<ApiResponse<object>>> GetStats()
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var totalForms = await _db.Forms
            .CountAsync(f => f.UserId == user.Id && f.DeletedAt == null);

        var totalResponses = await _db.Responses
            .CountAsync(r => r.Form!.UserId == user.Id && r.Form.DeletedAt == null);

        var totalFeedbackGiven = await _db.Feedbacks
            .CountAsync(f => f.UserId == user.Id);

        return Ok(new ApiResponse<object>(200, "OK", new UserStatsResponse
        {
            TotalForms = totalForms,
            TotalResponses = totalResponses,
            TotalFeedbackGiven = totalFeedbackGiven,
        }));
    }

    [HttpGet("me/responses")]
    public async Task<ActionResult<ApiResponse<object>>> GetMyResponses()
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var responses = await _db.Responses
            .Include(r => r.Form)
            .Include(r => r.Status)
            .Where(r => r.RespondentId == user.Id)
            .OrderByDescending(r => r.SubmittedAt)
            .Select(r => new MyResponseListItem
            {
                ResponseId = r.Id,
                FormId = r.FormId,
                FormTitle = r.Form != null ? r.Form.Title : "",
                FormLink = r.Form != null ? r.Form.FormLink : "",
                Status = r.Status != null ? r.Status.Status : "unknown",
                SubmittedAt = r.SubmittedAt ?? r.CreatedAt ?? DateTime.MinValue,
            })
            .ToListAsync();

        return Ok(new ApiResponse<object>(200, "OK", responses));
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }

    private static UserDto MapUserDto(User user) => new()
    {
        Id = user.Id,
        Fullname = user.Fullname,
        Username = user.Username,
        Email = user.Email,
        Role = user.Role,
        ProfileImage = user.ProfileImage,
        Birthdate = user.Birthdate?.ToString("yyyy-MM-dd"),
        IsActive = user.IsActive,
        CreatedAt = user.CreatedAt,
        UpdatedAt = user.UpdatedAt,
    };
}
