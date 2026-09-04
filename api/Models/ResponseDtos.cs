namespace FormUpAPI.Models;

public class SubmitResponseRequest
{
    public string? Token { get; set; }
    public string? RespondentName { get; set; }
    public List<AnswerRequest> Answers { get; set; } = new();
    public bool IsAutoSubmit { get; set; } = false;

    /// <summary>
    /// UUID sesi exam-monitoring dari POST exam-events (jika mode ujian).
    /// Dipakai untuk menautkan response ke sesi + backfill violation log.
    /// </summary>
    public string? ExamSessionId { get; set; }

    /// <summary>
    /// Total pelanggaran pindah tab menurut client. Jika null, server memakai
    /// hitungan dari sesi/log yang tersimpan.
    /// </summary>
    public int? TabSwitchCount { get; set; }

    /// <summary>
    /// Batch pelanggaran (tipe + timestamp) untuk client yang belum/tidak
    /// sempat mengirim incremental — digabung dengan log sesi bila ada.
    /// </summary>
    public List<ExamViolationItem> Violations { get; set; } = new();
}

public class AnswerRequest
{
    public int QuestionId { get; set; }
    public int? OptionId { get; set; }
    public string? AnswerValue { get; set; }
}

public class ResponseListItem
{
    public int Id { get; set; }
    public string? RespondentName { get; set; }
    public string Status { get; set; } = null!;
    public DateTime SubmittedAt { get; set; }
    public int TabSwitchCount { get; set; }
}

public class ResponseDetail
{
    public int Id { get; set; }
    public int FormId { get; set; }
    public string? RespondentName { get; set; }
    public string Status { get; set; } = null!;
    public DateTime SubmittedAt { get; set; }
    public int TabSwitchCount { get; set; }
    public List<ExamMonitoringViolationDto> Violations { get; set; } = new();
    public List<AnswerDetail> Answers { get; set; } = new();
}

public class AnswerDetail
{
    public int Id { get; set; }
    public int QuestionId { get; set; }
    public string Question { get; set; } = null!;
    public string? QuestionFormat { get; set; }
    public int TypeId { get; set; }
    public int? OptionId { get; set; }
    public string? OptionText { get; set; }
    public string? AnswerValue { get; set; }
    public double? ManualScore { get; set; }
    public bool? IsCorrectOverride { get; set; }
    public string? OverrideNote { get; set; }
}

public class UpdateResponseStatusRequest
{
    public int StatusId { get; set; }
}

public class ResponseResult
{
    public int ResponseId { get; set; }
    public int FormId { get; set; }
    public string FormTitle { get; set; } = null!;
    public bool ShowScore { get; set; }
    public double? Score { get; set; }
    public int CorrectCount { get; set; }
    public int WrongCount { get; set; }
    public int TotalQuestions { get; set; }
    public int ScorableQuestions { get; set; }
    public int AnsweredCount { get; set; }
    public List<ResultAnswer> Answers { get; set; } = new();
}

public class ResultAnswer
{
    public int QuestionId { get; set; }
    public int AnswerId { get; set; }
    public string Question { get; set; } = null!;
    public string? QuestionFormat { get; set; }
    public int TypeId { get; set; }
    public string? AnswerText { get; set; }
    public string? CorrectAnswer { get; set; }
    public bool? IsCorrect { get; set; }
    public double? ManualScore { get; set; }
    public bool? IsCorrectOverride { get; set; }
    public string? OverrideNote { get; set; }
    public List<string> Options { get; set; } = new();
    public List<string> SelectedOptions { get; set; } = new();
    public double? EarnedPoints { get; set; }
}

public class MyAttemptDto
{
    public int ResponseId { get; set; }
    public DateTime? SubmittedAt { get; set; }
    public bool ShowScore { get; set; }
    public double? Score { get; set; }
    public int CorrectCount { get; set; }
    public int WrongCount { get; set; }
}

public class UpdateAnswerScoreRequest
{
    public double? ManualScore { get; set; }
    public bool? IsCorrectOverride { get; set; }
    public string? OverrideNote { get; set; }
}

public class BulkScoreOverrideRequest
{
    public List<AnswerScoreOverrideItem> Overrides { get; set; } = new();
}

public class AnswerScoreOverrideItem
{
    public int AnswerId { get; set; }
    public double? ManualScore { get; set; }
    public bool? IsCorrectOverride { get; set; }
    public string? OverrideNote { get; set; }
}
