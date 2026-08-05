using System.Security.Claims;
using FormUpAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

[Route("api/forms/{formId}/analytics")]
[ApiController]
[EnableRateLimiting("creator")]
[Authorize]
public class AnalyticsController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public AnalyticsController(FormUpDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<object>>> GetAnalytics(int formId, CancellationToken ct)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null, ct);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions)
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .OrderBy(q => q.QuestionOrder)
            .ToListAsync(ct);

        var totalQuestions = questions.Count;
        var scorableQuestions = questions.Count(q =>
            !string.IsNullOrEmpty(q.CorrectAnswer) ||
            q.OptionQuestions.Any(o => o.IsCorrect == true));

        var responses = await _db.Responses
            .Include(r => r.Respondent)
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Option)
            .Where(r => r.FormId == formId)
            .OrderByDescending(r => r.SubmittedAt)
            .ToListAsync(ct);

        var respondents = new List<RespondentAnalytics>();
        var allScores = new List<double>();

        foreach (var response in responses)
        {
            var answers = new List<AnswerAnalytics>();
            var answeredCount = 0;
            var correctCount = 0;

            foreach (var q in questions)
            {
                var answer = response.RespondentAnswers
                    .FirstOrDefault(a => a.QuestionId == q.Id);

                if (answer != null)
                    answeredCount++;

                var answerText = GetAnswerText(answer, q);
                var correctAnswer = GetCorrectAnswerText(q);
                var isCorrect = IsAnswerCorrect(answer, q);

                if (isCorrect == true)
                    correctCount++;

                answers.Add(new AnswerAnalytics
                {
                    QuestionId = q.Id,
                    Question = q.Question1,
                    TypeId = q.TypeId,
                    AnswerText = answerText,
                    CorrectAnswer = correctAnswer,
                    IsCorrect = isCorrect,
                });
            }

            double? score = scorableQuestions > 0
                ? Math.Round((double)correctCount / scorableQuestions * 100, 1)
                : null;

            if (score.HasValue)
                allScores.Add(score.Value);

            respondents.Add(new RespondentAnalytics
            {
                ResponseId = response.Id,
                RespondentName = response.Respondent?.Fullname ?? response.RespondentName,
                SubmittedAt = response.SubmittedAt ?? response.CreatedAt ?? DateTime.MinValue,
                AnsweredCount = answeredCount,
                TotalQuestions = totalQuestions,
                CorrectCount = correctCount,
                ScorableQuestions = scorableQuestions,
                Score = score,
                Answers = answers,
            });
        }

        var averageScore = allScores.Count > 0
            ? Math.Round(allScores.Average(), 1)
            : (double?)null;

        return Ok(new ApiResponse<object>(200, "OK", new FormAnalyticsResponse
        {
            TotalResponses = responses.Count,
            TotalQuestions = totalQuestions,
            ScorableQuestions = scorableQuestions,
            AverageScore = averageScore,
            Respondents = respondents,
        }));
    }

    private static string? GetAnswerText(RespondentAnswer? answer, Question question)
    {
        if (answer == null) return null;
        if (answer.OptionId.HasValue && answer.Option != null)
            return answer.Option.OptionText;
        return answer.AnswerValue;
    }

    private static string? GetCorrectAnswerText(Question question)
    {
        if (!string.IsNullOrEmpty(question.CorrectAnswer))
            return question.CorrectAnswer;

        var correctOption = question.OptionQuestions
            .FirstOrDefault(o => o.IsCorrect == true);
        return correctOption?.OptionText;
    }

    private static bool? IsAnswerCorrect(RespondentAnswer? answer, Question question)
    {
        if (answer == null) return null;

        if (!string.IsNullOrEmpty(question.CorrectAnswer))
        {
            var isCorrect = string.Equals(answer.AnswerValue?.Trim(),
                question.CorrectAnswer.Trim(),
                StringComparison.OrdinalIgnoreCase);
            return isCorrect ? true : false;
        }

        var correctOption = question.OptionQuestions
            .FirstOrDefault(o => o.IsCorrect == true);
        if (correctOption != null)
        {
            return answer.OptionId == correctOption.Id;
        }

        return null;
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }
}
