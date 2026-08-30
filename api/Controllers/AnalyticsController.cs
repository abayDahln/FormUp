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

        var hasCustomPoints = questions.Any(q => q.Points.HasValue && q.Points.Value > 0 && (!string.IsNullOrEmpty(q.CorrectAnswer) || q.OptionQuestions.Any(o => o.IsCorrect == true)));
        var scoringDivisor = ResponseScorer.GetScoringDivisor(questions);
        double? averageScore = ComputeAverageScore(questions, scoringDivisor, hasCustomPoints, answerRows);

        var respondents = new List<RespondentAnalytics>();

        foreach (var response in pageResponses)
        {
            var answers = new List<AnswerAnalytics>();
            var answeredCount = 0;
            var correctCount = 0;

            foreach (var q in questions)
            {
                var questionAnswerRows = response.RespondentAnswers
                    .Where(a => a.QuestionId == q.Id)
                    .ToList();
                var answer = questionAnswerRows.FirstOrDefault();

                if (questionAnswerRows.Count > 0)
                    answeredCount++;

                var answerText = ResponseScorer.GetAnswerText(questionAnswerRows, q);
                var correctAnswer = ResponseScorer.GetCorrectAnswerText(q);
                var isCorrect = ResponseScorer.IsAnswerCorrect(questionAnswerRows, q);

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

            double? score = null;
            if (hasCustomPoints)
            {
                double earned = 0;
                foreach (var q in questions)
                {
                    var questionAnswerRows = response.RespondentAnswers.Where(a => a.QuestionId == q.Id).ToList();
                    if (ResponseScorer.IsAnswerCorrect(questionAnswerRows, q) == true)
                    {
                        earned += (q.Points ?? 1);
                    }
                }
                score = Math.Round(earned, 1);
            }
            else if (scoringDivisor > 0)
            {
                score = Math.Min(100.0, Math.Round((double)correctCount / scoringDivisor * 100, 1));
            }

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
        bool hasCustomPoints,
        List<(int ResponseId, int QuestionId, int? OptionId, string? AnswerValue)> answerRows)
    {
        if (scorableQuestions == 0 && !hasCustomPoints)
            return null;

        var correctByText = new Dictionary<int, string>();
        var correctOptionsByQuestion = new Dictionary<int, HashSet<int>>();
        var pointsByQuestion = new Dictionary<int, int>();
        foreach (var q in questions)
        {
            pointsByQuestion[q.Id] = q.Points ?? 1;
            if (q.OptionQuestions.Any(o => o.IsCorrect == true))
                correctOptionsByQuestion[q.Id] = q.OptionQuestions
                    .Where(o => o.IsCorrect == true)
                    .Select(o => o.Id)
                    .ToHashSet();
            if (!string.IsNullOrEmpty(q.CorrectAnswer))
                correctByText[q.Id] = q.CorrectAnswer.Trim();
        }

        var scores = new List<double>();
        foreach (var group in answerRows.GroupBy(a => a.ResponseId))
        {
            var correctCount = 0;
            double earnedPoints = 0;
            foreach (var q in questions)
            {
                var rows = group.Where(r => r.QuestionId == q.Id).ToList();
                var isCorr = ResponseScorer.IsAnswerCorrect(rows, q) == true;

                if (isCorr)
                {
                    correctCount++;
                    earnedPoints += pointsByQuestion.TryGetValue(q.Id, out var pt) ? pt : 1;
                }
            }

            if (hasCustomPoints)
            {
                scores.Add(Math.Round(earnedPoints, 1));
            }
            else if (scorableQuestions > 0)
            {
                scores.Add(Math.Min(100.0, Math.Round((double)correctCount / scorableQuestions * 100, 1)));
            }
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