namespace FormUpAPI.Models;

public class UpdateFormRequest
{
    public string? Title { get; set; }
    public string? Description { get; set; }
    public string? DescriptionFormat { get; set; }
    public string? BannerImage { get; set; }
    public string? FormLink { get; set; }
}

public class CreateFormRequest
{
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public string? DescriptionFormat { get; set; }
    public string? BannerImage { get; set; }
}

public class FormResponse
{
    public int Id { get; set; }
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public string? DescriptionFormat { get; set; }
    public string? BannerImage { get; set; }
    public string FormLink { get; set; } = null!;
    public string Status { get; set; } = null!;
    public int ResponseCount { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class FormDetailResponse
{
    public int Id { get; set; }
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public string? DescriptionFormat { get; set; }
    public string? BannerImage { get; set; }
    public string FormLink { get; set; } = null!;
    public string Status { get; set; } = null!;
    public int ResponseCount { get; set; }
    public FormSettingDto? Settings { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class FormSettingDto
{
    public int FormTypeId { get; set; }
    public bool? ShowScore { get; set; }
    public bool? RandomizeQuestions { get; set; }
    public int? TimerDuration { get; set; }
    public bool? OneResponse { get; set; }
    public bool? RequiredLogin { get; set; }
    public DateTime? OpenFormTime { get; set; }
    public DateTime? CloseFormTime { get; set; }
}

public class UpdateFormSettingsRequest
{
    public int? FormTypeId { get; set; }
    public bool? ShowScore { get; set; }
    public bool? RandomizeQuestions { get; set; }
    public string? FormToken { get; set; }
    public int? TimerDuration { get; set; }
    public bool? OneResponse { get; set; }
    public bool? RequiredLogin { get; set; }
    public DateTime? OpenFormTime { get; set; }
    public DateTime? CloseFormTime { get; set; }
}

public class PublicFormDetails
{
    public int Id { get; set; }
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public string? DescriptionFormat { get; set; }
    public string? BannerImage { get; set; }
    public bool RequiresToken { get; set; }
    public bool RequiresLogin { get; set; }
    public bool OneResponse { get; set; }
    public bool IsOwner { get; set; }
    public int? FormTypeId { get; set; }
    public bool? ShowScore { get; set; }
    public int? TimerDuration { get; set; }
    public bool? RandomizeQuestions { get; set; }
    public DateTime? OpenFormTime { get; set; }
    public DateTime? CloseFormTime { get; set; }
    public int QuestionCount { get; set; }
}

public class PublicQuestionsRequest
{
    public string? Token { get; set; }
    public string? Name { get; set; }
}

public class PublicQuestionsResponse
{
    public int FormId { get; set; }
    public List<QuestionResponse> Questions { get; set; } = new();
}

public class ShareInfoResponse
{
    public string FormLink { get; set; } = null!;
    public string ShareUrl { get; set; } = null!;
    public bool RequiresToken { get; set; }
    public bool HasToken { get; set; }
    public string QrCodeUrl { get; set; } = null!;
}
