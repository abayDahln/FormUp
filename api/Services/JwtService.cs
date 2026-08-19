using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using FormUpAPI.Models;
using Microsoft.IdentityModel.Tokens;

namespace FormUpAPI.Services;

public class JwtService
{
    private readonly string _key;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _accessTokenMinutes;

    public JwtService(IConfiguration configuration)
    {
        var jwtSettings = configuration.GetSection("Jwt");
        _key = Environment.GetEnvironmentVariable("JWT_KEY") ?? jwtSettings["Key"] ?? "";
        _issuer = jwtSettings["Issuer"] ?? "FormUpAPI";
        _audience = jwtSettings["Audience"] ?? "FormUpClient";
        _accessTokenMinutes = int.TryParse(jwtSettings["AccessTokenMinutes"], out var exp) ? exp : 60;

        if (_key.Trim() is "" or "your-super-secret-key-at-least-32-characters" ||
            _key.Trim().Length < 32)
            throw new InvalidOperationException(
                "JWT_KEY memakai nilai default yang tidak aman. Ganti dengan nilai acak yang panjang.");
    }

    public (string token, DateTime expiresAt) GenerateToken(User user)
    {
        var expiresAt = DateTime.UtcNow.AddMinutes(_accessTokenMinutes);
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_key));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.Name, user.Username ?? user.Fullname),
            new Claim(ClaimTypes.Role, user.Role ?? "USER"),
        };

        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _audience,
            claims: claims,
            expires: expiresAt,
            signingCredentials: credentials
        );

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }

    public ClaimsPrincipal? ValidateToken(string token)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_key));

        try
        {
            var handler = new JwtSecurityTokenHandler();
            return handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = key,
                ValidateIssuer = true,
                ValidIssuer = _issuer,
                ValidateAudience = true,
                ValidAudience = _audience,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromMinutes(30)
            }, out _);
        }
        catch
        {
            return null;
        }
    }
}
