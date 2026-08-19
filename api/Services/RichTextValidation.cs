using System.Text.Json;

namespace FormUpAPI.Services;

public static class RichTextValidation
{
    public const string Delta = "delta";

    public const string Text = "text";

    public static string FormatOf(string? content)
    {
        if (string.IsNullOrWhiteSpace(content)) return "";
        return IsDeltaJson(content) ? Delta : Text;
    }

    public static bool TryValidate(string? content, out string? error)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            error = null;
            return true;
        }

        var trimmed = content.Trim();
        if (trimmed.StartsWith('[') && !IsDeltaJson(trimmed))
        {
            error = "Konten diawali '[' tetapi bukan Delta JSON yang valid";
            return false;
        }

        error = null;
        return true;
    }

    public static bool IsDeltaJson(string? content)
    {
        if (string.IsNullOrWhiteSpace(content)) return false;
        var trimmed = content.Trim();
        if (!trimmed.StartsWith('[')) return false;

        try
        {
            using var doc = JsonDocument.Parse(trimmed);
            if (doc.RootElement.ValueKind != JsonValueKind.Array) return false;

            foreach (var op in doc.RootElement.EnumerateArray())
            {
                if (op.ValueKind != JsonValueKind.Object) return false;
                if (!op.TryGetProperty("insert", out var insert)) return false;
                if (insert.ValueKind is not (JsonValueKind.String or JsonValueKind.Object))
                    return false;
            }

            return true;
        }
        catch (JsonException)
        {
            return false;
        }
    }
}
