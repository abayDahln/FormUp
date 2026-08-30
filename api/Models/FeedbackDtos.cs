namespace FormUpAPI.Models;

public class SubmitFeedbackRequest
{
    public string Reason { get; set; } = null!;
    public string? Description { get; set; }
    public int? ResponseId { get; set; }
}

public class FeedbackResponse
{
    public int Id { get; set; }
    public int FormId { get; set; }
    public string FormTitle { get; set; } = null!;
    public int? UserId { get; set; }
    public string UserName { get; set; } = null!;
    public string Reason { get; set; } = null!;
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class AdminFeedbackListItem
{
    public int Id { get; set; }
    public int FormId { get; set; }
    public string FormTitle { get; set; } = null!;
    public string FormLink { get; set; } = null!;
    public int? UserId { get; set; }
    public string UserName { get; set; } = null!;
    public string UserEmail { get; set; } = null!;
    public string Reason { get; set; } = null!;
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; }
}
