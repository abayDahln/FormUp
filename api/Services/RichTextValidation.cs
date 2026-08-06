using System.Text.Json;

namespace FormUpAPI.Services;

/// <summary>
/// Validasi &amp; deteksi format konten rich text.
/// Aplikasi mobile menyimpan teks pertanyaan/deskripsi berformat sebagai
/// Delta JSON (Quill). Helpers ini dipakai agar API tahu format mana yang
/// disimpan dan menolak Delta JSON yang rusak sebelum masuk DB.
/// </summary>
public static class RichTextValidation
{
    /// <summary>Format konten berupa Delta JSON (Quill).</summary>
    public const string Delta = "delta";

    /// <summary>Format konten berupa plain text biasa.</summary>
    public const string Text = "text";

    /// <summary>
    /// Deteksi format: <c>"delta"</c> jika Delta JSON valid, <c>"text"</c>
    /// untuk plain text, atau string kosong jika konten kosong.
    /// </summary>
    public static string FormatOf(string? content)
    {
        if (string.IsNullOrWhiteSpace(content)) return "";
        return IsDeltaJson(content) ? Delta : Text;
    }

    /// <summary>
    /// Validasi konten: jika diawali <c>[</c> maka harus Delta JSON yang valid.
    /// Mengembalikan pesan error via <paramref name="error"/> bila tidak valid.
    /// </summary>
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

    /// <summary>
    /// Apakah string merupakan Delta JSON yang valid: array objek, dan tiap
    /// objek memiliki properti <c>insert</c> bertipe string atau object (embed).
    /// </summary>
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
