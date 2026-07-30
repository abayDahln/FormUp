using System;
using System.ComponentModel.DataAnnotations;

namespace FormUpAPI.Models;

public class Feedback
{
    public int Id { get; set; }

    public int FormId { get; set; }

    public int UserId { get; set; }

    public int? ResponseId { get; set; }

    public string Reason { get; set; } = null!;

    public string? Description { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Form Form { get; set; } = null!;

    public virtual User User { get; set; } = null!;

    public virtual Response? Response { get; set; }
}
