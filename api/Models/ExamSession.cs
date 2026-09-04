using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

/// <summary>
/// Satu sesi pengerjaan form mode ujian oleh satu responden.
/// Dibuat/di-update secara incremental lewat POST exam-events selama
/// responden mengerjakan (heartbeat + event pelanggaran), sehingga owner
/// bisa memantau progres live dan data tidak hilang bila tab ditutup
/// sebelum submit. Setelah submit, <see cref="SubmittedResponseId"/>
/// diisi dan log pelanggaran yang yatim di-backfill ke response tersebut.
/// </summary>
public partial class ExamSession
{
    public int Id { get; set; }

    public int FormId { get; set; }

    /// <summary>UUID yang digenerate client (satu per upaya pengerjaan).</summary>
    public string SessionId { get; set; } = null!;

    public int? RespondentId { get; set; }

    public string? RespondentName { get; set; }

    public int? SubmittedResponseId { get; set; }

    public DateTime? StartedAt { get; set; }

    public DateTime? LastSeenAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual Form Form { get; set; } = null!;

    public virtual User? Respondent { get; set; }

    public virtual Response? SubmittedResponse { get; set; }

    public virtual ICollection<ExamViolationLog> ViolationLogs { get; set; } = new List<ExamViolationLog>();
}
