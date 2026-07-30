namespace FormUpAPI.Models;

public class UpdateProfileRequest
{
    public string? Fullname { get; set; }
    public string? Username { get; set; }
    public string? Birthdate { get; set; }
}

public class ChangePasswordRequest
{
    public string CurrentPassword { get; set; } = null!;
    public string NewPassword { get; set; } = null!;
}

public class UserStatsResponse
{
    public int TotalForms { get; set; }
    public int TotalResponses { get; set; }
    public int TotalFeedbackGiven { get; set; }
}

public class MyResponseListItem
{
    public int ResponseId { get; set; }
    public int FormId { get; set; }
    public string FormTitle { get; set; } = null!;
    public string FormLink { get; set; } = null!;
    public string Status { get; set; } = null!;
    public DateTime SubmittedAt { get; set; }
}
