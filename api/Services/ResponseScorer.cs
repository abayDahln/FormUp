using FormUpAPI.Models;

namespace FormUpAPI.Services;

public static class ResponseScorer
{
    public static int CountScorable(List<Question> questions) =>
        questions.Count(q => !string.IsNullOrEmpty(q.CorrectAnswer) || q.OptionQuestions.Any(o => o.IsCorrect == true));

    public static int CountRequiredScorable(List<Question> questions) =>
        questions.Count(q => q.IsRequired == true && (!string.IsNullOrEmpty(q.CorrectAnswer) || q.OptionQuestions.Any(o => o.IsCorrect == true)));

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

    public static string? GetCorrectAnswerText(Question question)
    {
        if (!string.IsNullOrEmpty(question.CorrectAnswer))
            return question.CorrectAnswer;
        return question.OptionQuestions.FirstOrDefault(o => o.IsCorrect == true)?.OptionText;
    }

    public static bool? IsAnswerCorrect(RespondentAnswer? answer, Question question)
    {
        if (answer == null) return null;

        if (!string.IsNullOrEmpty(question.CorrectAnswer))
        {
            return string.Equals(answer.AnswerValue?.Trim(),
                question.CorrectAnswer.Trim(),
                StringComparison.OrdinalIgnoreCase);
        }

        var correctOption = question.OptionQuestions.FirstOrDefault(o => o.IsCorrect == true);
        if (correctOption != null)
            return answer.OptionId == correctOption.Id;

        return null;
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

            var isCorrect = showScore ? IsAnswerCorrect(answer, q) : null;
            if (isCorrect == true)
                correctCount++;

            answers.Add(new ResultAnswer
            {
                QuestionId = q.Id,
                Question = q.Question1,
                QuestionFormat = q.QuestionFormat ?? RichTextValidation.FormatOf(q.Question1),
                TypeId = q.TypeId,
                AnswerText = GetAnswerText(answer, q),
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

        var scoringDivisor = GetScoringDivisor(questions);
        double? score = showScore && scoringDivisor > 0
            ? Math.Min(100.0, Math.Round((double)correctCount / scoringDivisor * 100, 1))
            : null;

        return new ResponseResult
        {
            ResponseId = response.Id,
            FormId = form.Id,
            FormTitle = form.Title,
            ShowScore = showScore,
            Score = score,
            CorrectCount = showScore ? correctCount : 0,
            WrongCount = showScore ? answeredCount - correctCount : 0,
            TotalQuestions = questions.Count,
            ScorableQuestions = scorable,
            AnsweredCount = answeredCount,
            Answers = answers,
        };
    }
}
