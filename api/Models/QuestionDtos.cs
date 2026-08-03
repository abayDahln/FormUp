namespace FormUpAPI.Models;

public class CreateOptionRequest
{
    public string OptionText { get; set; } = null!;
    public bool? IsCorrect { get; set; }
}

public class QuestionResponse
{
    public int Id { get; set; }
    public int FormId { get; set; }
    public int TypeId { get; set; }
    public string Question { get; set; } = null!;
    public int QuestionOrder { get; set; }
    public string? QuestionImage { get; set; }
    public string? QuestionAudio { get; set; }
    public bool? IsRequired { get; set; }
    public string? CorrectAnswer { get; set; }
    public bool? RandomizeOptions { get; set; }
    public List<OptionResponse> Options { get; set; } = new();
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class OptionResponse
{
    public int Id { get; set; }
    public string OptionText { get; set; } = null!;
    public string? OptionImage { get; set; }
    public bool? IsCorrect { get; set; }
    public int OptionOrder { get; set; }
}

public class SaveQuestionsRequest
{
    public List<QuestionItem> Questions { get; set; } = new();
}

public class QuestionItem
{
    public int? Id { get; set; }
    public int TypeId { get; set; }
    public string Question { get; set; } = null!;
    public int? QuestionOrder { get; set; }
    public string? QuestionImage { get; set; }
    public string? QuestionAudio { get; set; }
    public bool? IsRequired { get; set; }
    public string? CorrectAnswer { get; set; }
    public bool? RandomizeOptions { get; set; }
    public List<CreateOptionRequest>? Options { get; set; }
}

public class ImportQuestionsResult
{
    public int TotalImported { get; set; }
    public int TotalSkipped { get; set; }
    public List<string> Errors { get; set; } = new();
}
