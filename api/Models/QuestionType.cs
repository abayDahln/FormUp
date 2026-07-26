using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class QuestionType
{
    public int Id { get; set; }

    public string Type { get; set; } = null!;

    public DateTime? CreatedAt { get; set; }

    public virtual ICollection<Question> Questions { get; set; } = new List<Question>();
}
