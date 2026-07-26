using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class OptionQuestion
{
    public int Id { get; set; }

    public int QuestionId { get; set; }

    public int OptionOrder { get; set; }

    public string? OptionText { get; set; }

    public string? OptionImage { get; set; }

    public bool? IsCorrect { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual Question Question { get; set; } = null!;

    public virtual ICollection<RespondentAnswer> RespondentAnswers { get; set; } = new List<RespondentAnswer>();
}
