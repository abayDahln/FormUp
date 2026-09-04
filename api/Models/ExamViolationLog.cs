using System;

namespace FormUpAPI.Models;

/// <summary>
/// Satu kejadian pelanggaran mode ujian (pindah tab, copy/paste, dst)
/// dengan timestamp-nya, terpisah dari data jawaban. Sumber kebenaran
/// untuk histori pelanggaran per responden — bukan sekadar angka total.
/// </summary>
public partial class ExamViolationLog
{
    public int Id { get; set; }

    public int ExamSessionId { get; set; }

    /// <summary>
    /// Diisi saat response disubmit (backfill dari sesi). Null selama
    /// responden masih mengerjakan / bila menutup tab sebelum submit.
    /// </summary>
    public int? ResponseId { get; set; }

    /// <summary>
    /// Jenis pelanggaran: tab_switch, window_blur, copy_attempt,
    /// paste_attempt, context_menu. Lihat <see cref="ExamEventTypes"/>.
    /// </summary>
    public string ViolationType { get; set; } = null!;

    /// <summary>Waktu kejadian menurut client (fallback: waktu server).</summary>
    public DateTime? OccurredAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual ExamSession ExamSession { get; set; } = null!;

    public virtual Response? Response { get; set; }
}
