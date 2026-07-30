using System.Text.RegularExpressions;
using FormUpAPI.Models;
using FormUpAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

[Route("api/[controller]")]
[ApiController]
public class AuthController : ControllerBase
{
    private readonly FormUpDbContext _db;
    private readonly JwtService _jwt;
    private readonly EmailService _email;

    public AuthController(FormUpDbContext db, JwtService jwt, EmailService email)
    {
        _db = db;
        _jwt = jwt;
        _email = email;
    }

    [HttpPost("register")]
    public async Task<ActionResult<ApiResponse<object>>> Register([FromBody] RegisterRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Fullname))
            return BadRequest(new ApiResponse<object>(400, "Fullname is required"));

        if (string.IsNullOrWhiteSpace(request.Username) || request.Username.Length < 3)
            return BadRequest(new ApiResponse<object>(400, "Username must be at least 3 characters"));

        if (string.IsNullOrWhiteSpace(request.Email) || !Regex.IsMatch(request.Email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
            return BadRequest(new ApiResponse<object>(400, "Valid email is required"));

        if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length < 8)
            return BadRequest(new ApiResponse<object>(400, "Password must be at least 8 characters"));

        if (await _db.Users.AnyAsync(u => u.Email == request.Email))
            return Conflict(new ApiResponse<object>(409, "Email already registered"));

        if (await _db.Users.AnyAsync(u => u.Username == request.Username))
            return Conflict(new ApiResponse<object>(409, "Username already taken"));

        var user = new User
        {
            Fullname = request.Fullname,
            Username = request.Username,
            Email = request.Email,
            Password = PasswordHelper.Hash(request.Password),
            Role = "USER",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
        };

        if (DateOnly.TryParse(request.Birthdate, out var birthdate))
            user.Birthdate = birthdate;

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var (token, expiresAt) = _jwt.GenerateToken(user);

        return CreatedAtAction(nameof(Register), new ApiResponse<object>(201, "User registered successfully", new AuthResponse
        {
            Token = token,
            ExpiresAt = expiresAt,
            User = MapUserDto(user),
        }));
    }

    [HttpPost("login")]
    public async Task<ActionResult<ApiResponse<object>>> Login([FromBody] LoginRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(new ApiResponse<object>(400, "Email and password are required"));

        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == request.Email);

        if (user == null || !PasswordHelper.Verify(request.Password, user.Password))
            return Unauthorized(new ApiResponse<object>(401, "Invalid email or password"));

        if (user.IsActive == false)
            return Unauthorized(new ApiResponse<object>(401, "Account is deactivated"));

        var (token, expiresAt) = _jwt.GenerateToken(user);

        return Ok(new ApiResponse<object>(200, "Login successful", new AuthResponse
        {
            Token = token,
            ExpiresAt = expiresAt,
            User = MapUserDto(user),
        }));
    }

    [HttpPost("refresh")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<object>>> Refresh()
    {
        var userIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return Unauthorized(new ApiResponse<object>(401, "Invalid token"));

        var user = await _db.Users.FindAsync(userId);
        if (user == null || user.IsActive == false)
            return Unauthorized(new ApiResponse<object>(401, "User not found or deactivated"));

        var (token, expiresAt) = _jwt.GenerateToken(user);

        return Ok(new ApiResponse<object>(200, "Token refreshed", new
        {
            token,
            expires_at = expiresAt,
        }));
    }

    [HttpPost("forgot-password")]
    public async Task<ActionResult<ApiResponse<object>>> ForgotPassword([FromBody] ForgotPasswordRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(new ApiResponse<object>(400, "Email is required"));

        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
        if (user == null)
            return Ok(new ApiResponse<object>(200, "If the email exists, an OTP has been sent"));

        var existingTokens = await _db.PasswordResetTokens
            .Where(t => t.UserId == user.Id && !t.IsUsed && t.ExpiresAt > DateTime.UtcNow)
            .ToListAsync();
        _db.PasswordResetTokens.RemoveRange(existingTokens);

        var otp = Random.Shared.Next(100_000, 999_999).ToString();
        _db.PasswordResetTokens.Add(new PasswordResetToken
        {
            UserId = user.Id,
            Otp = otp,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
            CreatedAt = DateTime.UtcNow,
        });
        await _db.SaveChangesAsync();

        try
        {
            await _email.SendOtpAsync(user.Email, otp);
        }
        catch
        {
            return StatusCode(500, new ApiResponse<object>(500, "Failed to send email. Check SMTP configuration."));
        }

        return Ok(new ApiResponse<object>(200, "OTP has been sent to your email"));
    }

    [HttpPost("reset-password")]
    public async Task<ActionResult<ApiResponse<object>>> ResetPassword([FromBody] ResetPasswordRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Otp) || string.IsNullOrWhiteSpace(request.NewPassword))
            return BadRequest(new ApiResponse<object>(400, "Email, OTP, and new password are required"));

        if (request.NewPassword.Length < 8)
            return BadRequest(new ApiResponse<object>(400, "New password must be at least 8 characters"));

        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
        if (user == null)
            return BadRequest(new ApiResponse<object>(400, "Invalid request"));

        var token = await _db.PasswordResetTokens
            .FirstOrDefaultAsync(t =>
                t.UserId == user.Id &&
                t.Otp == request.Otp &&
                !t.IsUsed &&
                t.ExpiresAt > DateTime.UtcNow);

        if (token == null)
            return BadRequest(new ApiResponse<object>(400, "Invalid or expired OTP"));

        token.IsUsed = true;
        user.Password = PasswordHelper.Hash(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Password has been reset successfully"));
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
