using FormUpAPI.Models;

namespace FormUpAPI.Services;

// ponytail: skoring dipakai bersama oleh analytics dan endpoint hasil responden
public static class ResponseScorer
{
    public static int CountScorable(List<Question> questions) =>
        questions.Count(q => !string.IsNullOrEmpty(q.CorrectAnswer) || q.OptionQuestions.Any(o => o.IsCorrect == true));

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
        // ponytail: grading (jawaban benar, skor, benar/salah) hanya muncul jika showScore aktif
        var showScore = form.FormSetting?.ShowScore == true;
        var scorable = CountScorable(questions);
        var answeredCount = 0;
        var correctCount = 0;
        var answers = new List<ResultAnswer>();

        foreach (var q in questions.OrderBy(q => q.QuestionOrder))
        {
            var answer = response.RespondentAnswers.FirstOrDefault(a => a.QuestionId == q.Id);
            if (answer != null)
                answeredCount++;

            var isCorrect = showScore ? IsAnswerCorrect(answer, q) : null;
            if (isCorrect == true)
                correctCount++;

            answers.Add(new ResultAnswer
            {
                QuestionId = q.Id,
                Question = q.Question1,
                TypeId = q.TypeId,
                AnswerText = GetAnswerText(answer, q),
                CorrectAnswer = showScore ? GetCorrectAnswerText(q) : null,
                IsCorrect = isCorrect,
            });
        }

        double? score = showScore && scorable > 0
            ? Math.Round((double)correctCount / scorable * 100, 1)
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
