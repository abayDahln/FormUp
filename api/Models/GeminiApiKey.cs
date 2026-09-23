namespace FormUpAPI.Models;

/// <summary>
/// Stok API key Gemini yang dibagikan ke user lewat kode redeem.
/// Satu key punya satu kode/PW (disimpan sebagai hash <c>salt.hash</c>
/// PBKDF2-SHA256, sama seperti password user). Kode bisa dipakai banyak
/// user; siapa menebus dicatat di <see cref="GeminiApiKeyRedemption"/>.
/// Isi tabel ini manual via SQL (tak ada endpoint admin).
/// </summary>
public class GeminiApiKey
{
    public int Id { get; set; }

    /// <summary>Label bebas, mis. "Kelas XII-A". Ditampilkan ke user.</summary>
    public string? Label { get; set; }

    /// <summary>
    /// API key Gemini asli (plaintext — harus bisa dikembalikan ke user
    /// saat redeem berhasil).
    /// </summary>
    public string ApiKey { get; set; } = null!;

    /// <summary>Hash kode redeem, format <c>salt.hash</c> (PasswordHelper).</summary>
    public string CodeHash { get; set; } = null!;

    public bool IsActive { get; set; } = true;

    /// <summary>Total redeem berhasil (semua user).</summary>
    public int RedeemedCount { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual ICollection<GeminiApiKeyRedemption> Redemptions { get; set; } = new List<GeminiApiKeyRedemption>();
}

/// <summary>
/// Jejak siapa menebus key apa (idempoten per pasangan user+key).
/// </summary>
public class GeminiApiKeyRedemption
{
    public int Id { get; set; }

    public int KeyId { get; set; }

    public int UserId { get; set; }

    public DateTime? RedeemedAt { get; set; }

    public virtual GeminiApiKey Key { get; set; } = null!;

    public virtual User User { get; set; } = null!;
}
