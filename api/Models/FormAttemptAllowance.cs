namespace FormUpAPI.Models;

/// <summary>
/// Jatah pengisian ulang per responden per form (one-response retake).
/// Reset sesi oleh owner TIDAK menghapus respons yang sudah disubmit —
/// sebagai gantinya baris ini bertambah, sehingga responden boleh submit
/// lagi tanpa kehilangan riwayat. Draft ("new") ikut dibersihkan saat reset.
/// </summary>
public class FormAttemptAllowance
{
    public int Id { get; set; }

    public int FormId { get; set; }

    public int? RespondentId { get; set; }

    public string? RespondentName { get; set; }

    /// <summary>Tambahan kesempatan submit di luar bawaan 1x one-response.</summary>
    public int ExtraAttempts { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual Form Form { get; set; } = null!;

    public virtual User? Respondent { get; set; }
}
