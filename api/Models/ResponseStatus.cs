using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class ResponseStatus
{
    public int Id { get; set; }

    public string Status { get; set; } = null!;

    public DateTime? CreatedAt { get; set; }

    public virtual ICollection<Response> Responses { get; set; } = new List<Response>();
}
