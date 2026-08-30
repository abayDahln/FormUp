namespace FormUpAPI.Models;

/// <summary>
/// Legacy helper - semua pengecekan waktu kritis (OTP, open/close form)
/// sekarang memakai <see cref="DateTime.UtcNow"/> langsung.
/// Simpan UTC di DB & API, konversi ke timezone user di client.
/// </summary>
public static class JakartaTime
{
    private static readonly TimeZoneInfo _zone = TimeZoneInfo.FindSystemTimeZoneById(
        OperatingSystem.IsWindows() ? "SE Asia Standard Time" : "Asia/Jakarta");

    // Legacy: tetap ada untuk kompatibilitas, tapi untuk OTP & open/close gunakan DateTime.UtcNow / JakartaTime.UtcNow
    public static DateTime Now => TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, _zone);

    /// <summary>UTC sekarang - gunakan untuk OTP, open/close, dan timestamp baru.</summary>
    public static DateTime UtcNow => DateTime.UtcNow;
}
