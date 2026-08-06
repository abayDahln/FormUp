namespace FormUpAPI.Models;

public class FormAnalyticsResponse
{
    public int TotalResponses { get; set; }
    public int TotalQuestions { get; set; }
    public int ScorableQuestions { get; set; }
    public double? AverageScore { get; set; }
    public List<RespondentAnalytics> Respondents { get; set; } = new();
}

public class RespondentAnalytics
{
    public int ResponseId { get; set; }
    public string? RespondentName { get; set; }
    public DateTime SubmittedAt { get; set; }
    public int AnsweredCount { get; set; }
    public int TotalQuestions { get; set; }
    public int CorrectCount { get; set; }
    public int ScorableQuestions { get; set; }
    public double? Score { get; set; }
    public List<AnswerAnalytics> Answers { get; set; } = new();
}

public class AnswerAnalytics
{
    public int QuestionId { get; set; }
    public string Question { get; set; } = null!;
    public string? QuestionFormat { get; set; }
    public int TypeId { get; set; }
    public string? AnswerText { get; set; }
    public string? CorrectAnswer { get; set; }
    public bool? IsCorrect { get; set; }
}
