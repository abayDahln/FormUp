using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class FormSetting
{
    public int Id { get; set; }

    public int FormId { get; set; }

    public bool? ShowScore { get; set; }

    public bool? RandomizeQuestions { get; set; }

    public string? FormToken { get; set; }

    public int? TimerDuration { get; set; }

    public bool? OneResponse { get; set; }

    public DateTime? CloseFormTime { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual Form Form { get; set; } = null!;
}
