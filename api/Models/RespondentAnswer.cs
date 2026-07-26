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

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual OptionQuestion? Option { get; set; }

    public virtual Question Question { get; set; } = null!;

    public virtual Response Response { get; set; } = null!;
}
