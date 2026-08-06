using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class Question
{
    public int Id { get; set; }

    public int FormId { get; set; }

    public int TypeId { get; set; }

    public string Question1 { get; set; } = null!;

    /// <summary>Format konten pertanyaan: "delta" (Quill Delta JSON) atau "text".</summary>
    public string? QuestionFormat { get; set; }

    public int QuestionOrder { get; set; }

    public string? QuestionImage { get; set; }

    public string? QuestionAudio { get; set; }

    public bool? IsRequired { get; set; }

    public string? CorrectAnswer { get; set; }

    public bool? RandomizeOptions { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public DateTime? DeletedAt { get; set; }

    public virtual Form Form { get; set; } = null!;

    public virtual ICollection<OptionQuestion> OptionQuestions { get; set; } = new List<OptionQuestion>();

    public virtual ICollection<RespondentAnswer> RespondentAnswers { get; set; } = new List<RespondentAnswer>();

    public virtual QuestionType Type { get; set; } = null!;
}
