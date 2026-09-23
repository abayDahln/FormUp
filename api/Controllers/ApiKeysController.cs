using System.Security.Claims;
using FormUpAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

/// <summary>
/// Redeem API key Gemini dengan kode. Wajib login; tiap key punya satu
/// kode/PW (hash). Kode bisa dipakai banyak user.
/// </summary>
[Route("api/api-keys")]
[ApiController]
[Authorize]
public class ApiKeysController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public ApiKeysController(FormUpDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Tukar kode redeem menjadi API key Gemini.
    /// </summary>
    /// <remarks>
    /// Rate-limit "auth" (10/mnt) agar kode tak bisa di-brute-force.
    /// Kode salah / key nonaktif selalu 404 dengan pesan sama agar tak
    /// membocorkan key mana yang ada.
    /// </remarks>
    [HttpPost("redeem")]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult<ApiResponse<object>>> Redeem([FromBody] RedeemApiKeyRequest request)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var code = request.Code?.Trim() ?? "";
        if (string.IsNullOrEmpty(code))
            return BadRequest(new ApiResponse<object>(400, "Kode wajib diisi."));

        // Kode dicocokkan terhadap hash tiap key aktif (kode disimpan
        // sebagai hash, bukan plaintext).
        var keys = await _db.GeminiApiKeys
            .Where(k => k.IsActive)
            .ToListAsync();

        GeminiApiKey? matched = null;
        foreach (var k in keys)
        {
            try
            {
                if (PasswordHelper.Verify(code, k.CodeHash))
                {
                    matched = k;
                    break;
                }
            }
            catch
            {
                // Hash korup: lewati, jangan bocorkan error internal.
            }
        }

        if (matched == null)
            return NotFound(new ApiResponse<object>(404, "Kode tidak valid."));

        // Catat redeem (idempoten: user yang sama menebus lagi tetap sukses).
        var already = await _db.GeminiApiKeyRedemptions
            .AnyAsync(r => r.KeyId == matched.Id && r.UserId == user.Id);
        if (!already)
        {
            _db.GeminiApiKeyRedemptions.Add(new GeminiApiKeyRedemption
            {
                KeyId = matched.Id,
                UserId = user.Id,
                RedeemedAt = DateTime.UtcNow,
            });
            matched.RedeemedCount++;
            matched.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        return Ok(new ApiResponse<object>(200, "OK", new
        {
            label = matched.Label,
            apiKey = matched.ApiKey,
        }));
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }
}
