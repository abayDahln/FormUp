namespace FormUpAPI.Models;

/// <summary>
/// Tipe event yang diterima POST exam-events. Hanya tipe berprefix
/// pelanggaran yang dicatat ke <see cref="ExamViolationLog"/> dan dihitung;
/// sisanya (session_start, heartbeat) hanya memperbarui presence sesi.
/// Aturan counting: SATU event masuk = SATU pelanggaran. Client wajib
/// mengirim tepat 1 event per 1 siklus keluar-masuk (mis. hanya saat
/// tab disembunyikan / app di-pause — BUKAN saat kembali/focus/resume),
/// kalau tidak hitungan akan ganda.
/// </summary>
public static class ExamEventTypes
{
    public const string SessionStart = "session_start";
    public const string Heartbeat = "heartbeat";

    public const string TabSwitch = "tab_switch";
    public const string WindowBlur = "window_blur";
    public const string CopyAttempt = "copy_attempt";
    public const string PasteAttempt = "paste_attempt";
    public const string ContextMenu = "context_menu";

    public static readonly HashSet<string> PresenceOnly = new(StringComparer.OrdinalIgnoreCase)
    {
        SessionStart, Heartbeat,
    };

    public static readonly HashSet<string> Violations = new(StringComparer.OrdinalIgnoreCase)
    {
        TabSwitch, WindowBlur, CopyAttempt, PasteAttempt, ContextMenu,
    };

    public static bool IsViolation(string? type) =>
        !string.IsNullOrWhiteSpace(type) && Violations.Contains(type.Trim());

    public static bool IsKnown(string? type) =>
        !string.IsNullOrWhiteSpace(type) &&
        (PresenceOnly.Contains(type.Trim()) || Violations.Contains(type.Trim()));

    /// <summary>Normalisasi alias umum dari client ke tipe kanonis.</summary>
    public static string Normalize(string type) => type.Trim().ToLowerInvariant() switch
    {
        "tabswitch" or "tab-switch" or "visibility_hidden" or "app_paused" => TabSwitch,
        "blur" => WindowBlur,
        "copy" => CopyAttempt,
        "paste" => PasteAttempt,
        "right_click" or "rightclick" => ContextMenu,
        _ => type.Trim().ToLowerInvariant(),
    };
}

public class ExamEventRequest
{
    /// <summary>
    /// UUID sesi dari client. Kosong saat event pertama → server generate
    /// dan mengembalikannya; client wajib memakai ulang untuk event berikut.
    /// </summary>
    public string? SessionId { get; set; }

    public string? RespondentName { get; set; }

    /// <summary>Salah satu dari <see cref="ExamEventTypes"/> (alias umum diterima).</summary>
    public string Type { get; set; } = null!;

    /// <summary>Waktu kejadian di client (UTC). Null → waktu server.</summary>
    public DateTime? OccurredAt { get; set; }
}

public class ExamEventResult
{
    public string SessionId { get; set; } = null!;
    public int ViolationCount { get; set; }
    public int TabSwitchCount { get; set; }

    /// <summary>
    /// True bila batas pelanggaran tercapai dan form diset auto-submit —
    /// client harus segera auto-submit jawaban apa adanya.
    /// </summary>
    public bool ShouldAutoSubmit { get; set; }
}

public class ExamViolationItem
{
    public string Type { get; set; } = null!;
    public DateTime? OccurredAt { get; set; }
}

public class ExamMonitoringViolationDto
{
    public string Type { get; set; } = null!;
    public DateTime? OccurredAt { get; set; }
}

public class ExamMonitoringSessionDto
{
    public string? SessionId { get; set; }
    public int? ResponseId { get; set; }
    public string? RespondentName { get; set; }
    public int? RespondentId { get; set; }

    /// <summary>in_progress (mulai/belum submit) atau submitted.</summary>
    public string Status { get; set; } = "in_progress";

    /// <summary>Online bila ada event dalam 90 detik terakhir.</summary>
    public bool IsOnline { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? LastSeenAt { get; set; }
    public DateTime? SubmittedAt { get; set; }
    public int ViolationCount { get; set; }
    public int TabSwitchCount { get; set; }
    public List<ExamMonitoringViolationDto> Violations { get; set; } = new();
}
