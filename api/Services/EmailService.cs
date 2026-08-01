using System.Net;
using System.Net.Mail;

namespace FormUpAPI.Services;

public class EmailService
{
    private readonly string _smtpHost;
    private readonly int _smtpPort;
    private readonly string _smtpUser;
    private readonly string _smtpPass;
    private readonly string _fromEmail;
    private readonly string _fromName;

    public EmailService(IConfiguration configuration)
    {
        var smtp = configuration.GetSection("Smtp");
        _smtpHost = Environment.GetEnvironmentVariable("SMTP_HOST") ?? smtp["Host"] ?? "smtp.gmail.com";
        _smtpPort = int.TryParse(Environment.GetEnvironmentVariable("SMTP_PORT") ?? smtp["Port"], out var p) ? p : 587;
        _smtpUser = Environment.GetEnvironmentVariable("SMTP_USER") ?? smtp["User"] ?? "";
        _smtpPass = Environment.GetEnvironmentVariable("SMTP_PASS") ?? smtp["Pass"] ?? "";
        _fromEmail = Environment.GetEnvironmentVariable("SMTP_FROM") ?? smtp["FromEmail"] ?? _smtpUser;
        _fromName = smtp["FromName"] ?? "FormUp";
    }

    public async Task SendOtpAsync(string toEmail, string otp, string purpose)
    {
        using var client = new SmtpClient(_smtpHost, _smtpPort)
        {
            Credentials = new NetworkCredential(_smtpUser, _smtpPass),
            EnableSsl = true,
        };

        var (subject, heading) = purpose switch
        {
            "register" => ("FormUp — Verification OTP", "Verify Your Account"),
            _ => ("FormUp — Password Reset OTP", "Password Reset Request"),
        };

        var mail = new MailMessage
        {
            From = new MailAddress(_fromEmail, _fromName),
            Subject = subject,
            Body = $"""
            <h2>{heading}</h2>
            <p>Your OTP code is:</p>
            <h1 style="letter-spacing: 8px; font-size: 32px; background: #f4f4f4; padding: 12px 24px; text-align: center;">{otp}</h1>
            <p>This code expires in <strong>15 minutes</strong>.</p>
            <p>If you did not request this, please ignore this email.</p>
            <hr>
            <small>FormUp &copy; 2026</small>
            """,
            IsBodyHtml = true,
        };
        mail.To.Add(toEmail);

        await client.SendMailAsync(mail);
    }
}
