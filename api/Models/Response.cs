using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class Response
{
    public int Id { get; set; }

    public int FormId { get; set; }

    public int? RespondentId { get; set; }

    public string? RespondentName { get; set; }

    public int StatusId { get; set; }

    public DateTime? SubmittedAt { get; set; }

    /// <summary>
    /// Akumulasi pelanggaran pindah tab saat submit (disalin dari sesi
    /// exam-monitoring / dikirim client). Detail per kejadian ada di
    /// ExamViolationLog — kolom ini hanya angka ringkas untuk list/export.
    /// </summary>
    public int? TabSwitchCount { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual Form Form { get; set; } = null!;

    public virtual User? Respondent { get; set; }

    public virtual ICollection<RespondentAnswer> RespondentAnswers { get; set; } = new List<RespondentAnswer>();

    public virtual ICollection<ExamViolationLog> ExamViolationLogs { get; set; } = new List<ExamViolationLog>();

    public virtual ICollection<ExamSession> ExamSessions { get; set; } = new List<ExamSession>();

    public virtual ResponseStatus Status { get; set; } = null!;
}
