using System;
using System.Collections.Generic;

namespace FormUpAPI.Models;

public partial class Form
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public int StatusId { get; set; }

    public string Title { get; set; } = null!;

    public string? Description { get; set; }

    /// <summary>Format konten deskripsi: "delta" (Quill Delta JSON) atau "text".</summary>
    public string? DescriptionFormat { get; set; }

    public string? BannerImage { get; set; }

    public string FormLink { get; set; } = null!;

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public DateTime? DeletedAt { get; set; }

    public DateTime? TakenDownAt { get; set; }

    public virtual FormSetting? FormSetting { get; set; }

    public virtual ICollection<Question> Questions { get; set; } = new List<Question>();

    public virtual ICollection<Response> Responses { get; set; } = new List<Response>();

    public virtual FormStatus Status { get; set; } = null!;

    public virtual User User { get; set; } = null!;
}
