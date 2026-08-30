using FormUpAPI.Models;

namespace FormUpAPI.Services;

public static class ResponseScorer
{
    public static int CountScorable(List<Question> questions) =>
        questions.Count(q => q.Points.HasValue || !string.IsNullOrEmpty(q.CorrectAnswer) || q.OptionQuestions.Any(o => o.IsCorrect == true));

    public static int CountRequiredScorable(List<Question> questions) =>
        questions.Count(q => q.IsRequired == true && (q.Points.HasValue || !string.IsNullOrEmpty(q.CorrectAnswer) || q.OptionQuestions.Any(o => o.IsCorrect == true)));

    public static int GetScoringDivisor(List<Question> questions)
    {
        var requiredScorable = CountRequiredScorable(questions);
        if (requiredScorable > 0) return requiredScorable;
        var allScorable = CountScorable(questions);
        return allScorable > 0 ? allScorable : 0;
    }

    public static string? GetAnswerText(RespondentAnswer? answer, Question question)
    {
        if (answer == null) return null;
        if (answer.OptionId.HasValue && answer.Option != null)
            return answer.Option.OptionText;
        return answer.AnswerValue;
    }

    public static string? GetAnswerText(IEnumerable<RespondentAnswer>? answers, Question question)
    {
        var rows = answers?.ToList() ?? new List<RespondentAnswer>();
        if (rows.Count == 0)
            return null;

        if (question.TypeId == 3)
        {
            var parts = rows
                .Where(a => a.OptionId.HasValue && a.Option != null)
                .Select(a => a.Option!.OptionText)
                .Where(text => !string.IsNullOrWhiteSpace(text))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(text => text)
                .ToList();

            if (parts.Count > 0)
                return string.Join(", ", parts);

            var textParts = rows
                .Select(a => a.AnswerValue)
                .Where(v => !string.IsNullOrWhiteSpace(v))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(v => v)
                .ToList();

            return textParts.Count > 0 ? string.Join(", ", textParts) : null;
        }

        var first = rows
            .Select(a => GetAnswerText(a, question))
            .FirstOrDefault(v => !string.IsNullOrWhiteSpace(v));

        return first;
    }

    public static string? GetCorrectAnswerText(Question question)
    {
        if (!string.IsNullOrEmpty(question.CorrectAnswer))
            return question.CorrectAnswer;

        if (question.TypeId == 3)
        {
            var correctOptions = question.OptionQuestions
                .Where(o => o.IsCorrect == true)
                .OrderBy(o => o.OptionOrder)
                .Select(o => o.OptionText)
                .Where(text => !string.IsNullOrWhiteSpace(text))
                .ToList();

            return correctOptions.Count > 0 ? string.Join(", ", correctOptions) : null;
        }

        return question.OptionQuestions.FirstOrDefault(o => o.IsCorrect == true)?.OptionText;
    }

    private static bool HasDefinedCorrectAnswer(Question question)
    {
        return !string.IsNullOrEmpty(question.CorrectAnswer) || question.OptionQuestions.Any(o => o.IsCorrect == true);
    }

    public static bool? IsAnswerCorrect(RespondentAnswer? answer, Question question)
    {
        var rows = answer == null ? Enumerable.Empty<RespondentAnswer>() : new[] { answer };
        return IsAnswerCorrect(rows, question);
    }

    public static bool? IsAnswerCorrect(IEnumerable<RespondentAnswer>? answers, Question question)
    {
        var answerRows = answers?.ToList() ?? new List<RespondentAnswer>();
        return IsAnswerCorrectInternal(answerRows, question);
    }

    public static bool? IsAnswerCorrect(IEnumerable<(int ResponseId, int QuestionId, int? OptionId, string? AnswerValue)>? answers, Question question)
    {
        var answerRows = answers ?? Enumerable.Empty<(int ResponseId, int QuestionId, int? OptionId, string? AnswerValue)>();
        var selectedOptionIds = answerRows
            .Where(a => a.QuestionId == question.Id && a.OptionId.HasValue)
            .Select(a => a.OptionId!.Value)
            .Distinct()
            .OrderBy(id => id)
            .ToList();

        if (question.TypeId == 3)
        {
            var correctOptions = question.OptionQuestions
                .Where(o => o.IsCorrect == true)
                .Select(o => o.Id)
                .Distinct()
                .OrderBy(id => id)
                .ToList();

            if (!HasDefinedCorrectAnswer(question))
                return true;

            return selectedOptionIds.SequenceEqual(correctOptions);
        }

        var answerText = answerRows
            .Where(a => a.QuestionId == question.Id)
            .Select(a => a.AnswerValue)
            .FirstOrDefault(v => !string.IsNullOrWhiteSpace(v));

        return IsAnswerCorrectInternal(
            answerRows
                .Where(a => a.QuestionId == question.Id)
                .Select(a => new RespondentAnswer
                {
                    QuestionId = a.QuestionId,
                    OptionId = a.OptionId,
                    AnswerValue = a.AnswerValue,
                }),
            question);
    }

    private static bool? IsAnswerCorrectInternal(IEnumerable<RespondentAnswer> answerRows, Question question)
    {
        if (!HasDefinedCorrectAnswer(question))
            return true;

        if (question.TypeId == 3)
        {
            var selectedOptions = answerRows
                .Where(a => a.OptionId.HasValue)
                .Select(a => a.OptionId!.Value)
                .Distinct()
                .OrderBy(id => id)
                .ToList();

            var correctOptions = question.OptionQuestions
                .Where(o => o.IsCorrect == true)
                .Select(o => o.Id)
                .Distinct()
                .OrderBy(id => id)
                .ToList();

            return selectedOptions.SequenceEqual(correctOptions);
        }

        var answerText = answerRows
            .Select(a => GetAnswerText(a, question))
            .FirstOrDefault(v => !string.IsNullOrWhiteSpace(v));

        if (!string.IsNullOrEmpty(question.CorrectAnswer))
        {
            return string.Equals(answerText?.Trim(),
                question.CorrectAnswer.Trim(),
                StringComparison.OrdinalIgnoreCase);
        }

        var correctOption = question.OptionQuestions.FirstOrDefault(o => o.IsCorrect == true);
        if (correctOption != null)
            return answerRows.Any(a => a.OptionId == correctOption.Id);

        return true;
    }

    public static ResponseResult BuildResult(Form form, Response response, List<Question> questions)
    {
        var showScore = form.FormSetting?.ShowScore == true;
        var scorable = CountScorable(questions);
        var answeredCount = 0;
        var correctCount = 0;
        var answers = new List<ResultAnswer>();

        foreach (var q in questions.OrderBy(q => q.QuestionOrder))
        {
            var answerRows = response.RespondentAnswers
                .Where(a => a.QuestionId == q.Id)
                .ToList();
            var answer = answerRows.FirstOrDefault();

            if (answerRows.Count > 0)
                answeredCount++;

            var isCorrect = showScore ? IsAnswerCorrect(answerRows, q) : null;
            if (isCorrect == true)
                correctCount++;

            answers.Add(new ResultAnswer
            {
                QuestionId = q.Id,
                Question = q.Question1,
                QuestionFormat = q.QuestionFormat ?? RichTextValidation.FormatOf(q.Question1),
                TypeId = q.TypeId,
                AnswerText = GetAnswerText(answerRows, q),
                CorrectAnswer = showScore ? GetCorrectAnswerText(q) : null,
                IsCorrect = isCorrect,
                Options = q.OptionQuestions
                    .OrderBy(o => o.OptionOrder)
                    .Where(o => !string.IsNullOrEmpty(o.OptionText))
                    .Select(o => o.OptionText!)
                    .ToList(),
                SelectedOptions = answerRows
                    .Select(a => GetAnswerText(a, q))
                    .Where(t => !string.IsNullOrEmpty(t))
                    .Select(t => t!)
                    .ToList(),
            });
        }

        var hasCustomPoints = questions.Any(q => q.Points.HasValue && q.Points.Value > 0);

        double? score = null;
        if (showScore)
        {
            if (hasCustomPoints)
            {
                double earnedPoints = 0;
                foreach (var q in questions)
                {
                    var ansRows = response.RespondentAnswers.Where(a => a.QuestionId == q.Id).ToList();
                    if (IsAnswerCorrect(ansRows, q) == true)
                    {
                        earnedPoints += (q.Points ?? 1);
                    }
                }
                score = Math.Round(earnedPoints, 1);
            }
            else
            {
                var scoringDivisor = GetScoringDivisor(questions);
                score = scoringDivisor > 0
                    ? Math.Min(100.0, Math.Round((double)correctCount / scoringDivisor * 100, 1))
                    : null;
            }
        }

        return new ResponseResult
        {
            ResponseId = response.Id,
            FormId = form.Id,
            FormTitle = form.Title,
            ShowScore = showScore,
            Score = score,
            CorrectCount = showScore ? correctCount : 0,
            WrongCount = showScore ? answers.Count(a => a.IsCorrect == false) : 0,
            TotalQuestions = questions.Count,
            ScorableQuestions = scorable,
            AnsweredCount = answeredCount,
            Answers = answers,
        };
    }
}