using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class Response
{
    public int Id { get; set; }

    public int FormId { get; set; }

    public int? RespondentId { get; set; }

    public int StatusId { get; set; }

    public DateTime? SubmittedAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual Form Form { get; set; } = null!;

    public virtual User? Respondent { get; set; }

    public virtual ICollection<RespondentAnswer> RespondentAnswers { get; set; } = new List<RespondentAnswer>();

    public virtual ResponseStatus Status { get; set; } = null!;
}
