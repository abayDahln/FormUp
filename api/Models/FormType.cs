using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class FormType
{
    public int Id { get; set; }

    public string Type { get; set; } = null!;

    public DateTime? CreatedAt { get; set; }

    public virtual ICollection<FormSetting> FormSettings { get; set; } = new List<FormSetting>();
}
