using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class FormStatus
{
    public int Id { get; set; }

    public string Status { get; set; } = null!;

    public DateTime? CreatedAt { get; set; }

    public virtual ICollection<Form> Forms { get; set; } = new List<Form>();
}
