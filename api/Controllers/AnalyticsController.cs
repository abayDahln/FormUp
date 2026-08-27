using System.Security.Claims;
using FormUpAPI.Models;
using FormUpAPI.Services;
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
    public async Task<ActionResult<ApiResponse<object>>> GetAnalytics(int formId, [FromQuery] int? page, [FromQuery] int? pageSize, [FromQuery] string? search, CancellationToken ct)
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
        var scorableQuestions = ResponseScorer.CountScorable(questions);

        var responsesQuery = _db.Responses
            .Include(r => r.Respondent)
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Option)
            .Where(r => r.FormId == formId);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            responsesQuery = responsesQuery.Where(r =>
                (r.Respondent != null && r.Respondent.Fullname.Contains(term)) ||
                (r.RespondentName != null && r.RespondentName.Contains(term)));
        }

        // Paging di level database — tidak lagi memuat semua respon.
        var totalResponses = await responsesQuery.CountAsync(ct);

        var currentPage = page.GetValueOrDefault(1);
        var currentPageSize = pageSize.GetValueOrDefault(0);
        var paged = currentPageSize > 0;
        var pageResponses = paged
            ? await responsesQuery
                .OrderByDescending(r => r.SubmittedAt)
                .Skip((currentPage - 1) * currentPageSize)
                .Take(currentPageSize)
                .ToListAsync(ct)
            : await responsesQuery.OrderByDescending(r => r.SubmittedAt).ToListAsync(ct);

        // Skor semua responden untuk averageScore dihitung dari proyeksi ringan
        // (tanpa Include navigasi), bukan dari seluruh entity graph.
        var answerRowEntities = await _db.RespondentAnswers
            .AsNoTracking()
            .Where(a => a.Response.FormId == formId)
            .Select(a => new { a.ResponseId, a.QuestionId, a.OptionId, a.AnswerValue })
            .ToListAsync(ct);
        var answerRows = answerRowEntities
            .Select(r => (r.ResponseId, r.QuestionId, r.OptionId, r.AnswerValue))
            .ToList();

        var scoringDivisor = ResponseScorer.GetScoringDivisor(questions);
        double? averageScore = ComputeAverageScore(questions, scoringDivisor, answerRows);

        var respondents = new List<RespondentAnalytics>();

        foreach (var response in pageResponses)
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

                var answerText = ResponseScorer.GetAnswerText(answer, q);
                var correctAnswer = ResponseScorer.GetCorrectAnswerText(q);
                var isCorrect = ResponseScorer.IsAnswerCorrect(answer, q);

                if (isCorrect == true)
                    correctCount++;

                answers.Add(new AnswerAnalytics
                {
                    QuestionId = q.Id,
                    Question = q.Question1,
                    QuestionFormat = q.QuestionFormat ?? RichTextValidation.FormatOf(q.Question1),
                    TypeId = q.TypeId,
                    AnswerText = answerText,
                    CorrectAnswer = correctAnswer,
                    IsCorrect = isCorrect,
                });
            }

            double? score = scoringDivisor > 0
                ? Math.Min(100.0, Math.Round((double)correctCount / scoringDivisor * 100, 1))
                : null;

            respondents.Add(new RespondentAnalytics
            {
                ResponseId = response.Id,
                RespondentName = response.Respondent?.Fullname ?? response.RespondentName,
                SubmittedAt = response.SubmittedAt ?? response.CreatedAt ?? DateTime.MinValue,
                AnsweredCount = answeredCount,
                TotalQuestions = totalQuestions,
                CorrectCount = correctCount,
                ScorableQuestions = scoringDivisor > 0 ? scoringDivisor : scorableQuestions,
                Score = score,
                Answers = answers,
            });
        }

        if (paged)
        {
            return Ok(new ApiResponse<object>(200, "OK", new
            {
                TotalResponses = totalResponses,
                TotalQuestions = totalQuestions,
                ScorableQuestions = scorableQuestions,
                AverageScore = averageScore,
                Respondents = respondents,
                Page = currentPage,
                PageSize = currentPageSize,
            }));
        }

        return Ok(new ApiResponse<object>(200, "OK", new FormAnalyticsResponse
        {
            TotalResponses = totalResponses,
            TotalQuestions = totalQuestions,
            ScorableQuestions = scorableQuestions,
            AverageScore = averageScore,
            Respondents = respondents,
        }));
    }

    /// <summary>
    /// Hitung rata-rata skor seluruh respon form dari proyeksi baris jawaban
    /// ringan (ResponseId, QuestionId, OptionId, AnswerValue).
    /// </summary>
    private static double? ComputeAverageScore(
        List<Question> questions,
        int scorableQuestions,
        List<(int ResponseId, int QuestionId, int? OptionId, string? AnswerValue)> answerRows)
    {
        if (scorableQuestions == 0)
            return null;

        var correctByText = new Dictionary<int, string>();
        var correctOptionByQuestion = new Dictionary<int, int>();
        foreach (var q in questions)
        {
            var option = q.OptionQuestions.FirstOrDefault(o => o.IsCorrect == true);
            if (option != null)
                correctOptionByQuestion[q.Id] = option.Id;
            if (!string.IsNullOrEmpty(q.CorrectAnswer))
                correctByText[q.Id] = q.CorrectAnswer.Trim();
        }

        var scores = new List<double>();
        foreach (var group in answerRows.GroupBy(a => a.ResponseId))
        {
            var correctCount = 0;
            foreach (var row in group)
            {
                if (correctOptionByQuestion.TryGetValue(row.QuestionId, out var correctId))
                {
                    if (row.OptionId == correctId)
                        correctCount++;
                }
                else if (correctByText.TryGetValue(row.QuestionId, out var key))
                {
                    if (string.Equals(row.AnswerValue?.Trim(), key, StringComparison.OrdinalIgnoreCase))
                        correctCount++;
                }
            }

            scores.Add(Math.Min(100.0, Math.Round((double)correctCount / scorableQuestions * 100, 1)));
        }

        return scores.Count > 0 ? Math.Round(scores.Average(), 1) : null;
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }
}
