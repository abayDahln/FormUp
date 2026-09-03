using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class FormSetting
{
    public int Id { get; set; }

    public int FormId { get; set; }

    public int FormTypeId { get; set; }

    public bool? ShowScore { get; set; }

    public bool? RandomizeQuestions { get; set; }

    public string? FormToken { get; set; }

    public int? TimerDuration { get; set; }

    public bool? OneResponse { get; set; }

    public bool? RequiredLogin { get; set; }

    public DateTime? OpenFormTime { get; set; }

    public DateTime? CloseFormTime { get; set; }

    // FEAT-6: Mode Ujian - persistent flags (previously blocked, now stored typed)
    public bool? IsExamMode { get; set; }

    public bool? DisableCopyPaste { get; set; }

    public bool? DetectTabSwitch { get; set; }

    public bool? AutoSubmitOnTabSwitch { get; set; }

    public int? MaxTabSwitch { get; set; }

    // FEAT-9: Custom Theme per-form - typed fields (previously blocked)
    public string? ThemePrimaryColor { get; set; }

    public string? ThemeBackgroundColor { get; set; }

    public string? ThemeConfig { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual Form Form { get; set; } = null!;

    public virtual FormType? FormType { get; set; }
}
