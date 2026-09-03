using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class RespondentAnswer
{
    public int Id { get; set; }

    public int ResponseId { get; set; }

    public int QuestionId { get; set; }

    public int? OptionId { get; set; }

    public string? AnswerValue { get; set; }

    // AI-4: Smart Scoring Essay - manual override per answer (previously blocked, no endpoint)
    public double? ManualScore { get; set; }

    public bool? IsCorrectOverride { get; set; }

    public string? OverrideNote { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual OptionQuestion? Option { get; set; }

    public virtual Question Question { get; set; } = null!;

    public virtual Response Response { get; set; } = null!;
}
