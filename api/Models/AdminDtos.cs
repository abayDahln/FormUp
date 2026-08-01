namespace FormUpAPI.Models;

public class AdminUserListItem
{
    public int Id { get; set; }
    public string Fullname { get; set; } = null!;
    public string? Username { get; set; }
    public string Email { get; set; } = null!;
    public string Role { get; set; } = null!;
    public bool? IsActive { get; set; }
    public int FormCount { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
}

public class AdminUserDetailResponse
{
    public int Id { get; set; }
    public string Fullname { get; set; } = null!;
    public string? Username { get; set; }
    public string Email { get; set; } = null!;
    public string? Role { get; set; }
    public string? ProfileImage { get; set; }
    public string? Birthdate { get; set; }
    public bool? IsActive { get; set; }
    public int FormCount { get; set; }
    public int ResponseCount { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
}

public class AdminFormListItem
{
    public int Id { get; set; }
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public string FormLink { get; set; } = null!;
    public string Status { get; set; } = null!;
    public string OwnerName { get; set; } = null!;
    public string OwnerEmail { get; set; } = null!;
    public int ResponseCount { get; set; }
    public DateTime? TakenDownAt { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
}
