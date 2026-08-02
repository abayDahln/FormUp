namespace FormUpAPI.Services;

public static class FileValidation
{
    public const long MaxImageBytes = 10 * 1024 * 1024;
    public const long MaxAudioBytes = 20 * 1024 * 1024;
    public const long MaxImportBytes = 5 * 1024 * 1024;

    public static string? DetectImageExt(Stream s)
    {
        var sig = ReadBytes(s, 12);
        if (sig == null) return null;

        if (sig.Length >= 3 && sig[0] == 0xFF && sig[1] == 0xD8 && sig[2] == 0xFF) return ".jpg";
        if (sig.Length >= 8 && sig[0] == 0x89 && sig[1] == 0x50 && sig[2] == 0x4E && sig[3] == 0x47) return ".png";
        if (sig.Length >= 6 && (sig[0] == (byte)'G') && (sig[1] == (byte)'I') && (sig[2] == (byte)'F'))
        {
            var t = System.Text.Encoding.ASCII.GetString(sig, 3, 3);
            if (t is "87a" or "89a") return ".gif";
        }
        if (sig.Length >= 12
            && sig[0] == (byte)'R' && sig[1] == (byte)'I' && sig[2] == (byte)'F' && sig[3] == (byte)'F'
            && sig[8] == (byte)'W' && sig[9] == (byte)'E' && sig[10] == (byte)'B' && sig[11] == (byte)'P')
            return ".webp";

        return null;
    }

    public static string? DetectAudioExt(Stream s)
    {
        var sig = ReadBytes(s, 12);
        if (sig == null) return null;

        if (sig.Length >= 3 && sig[0] == (byte)'I' && sig[1] == (byte)'D' && sig[2] == (byte)'3') return ".mp3";
        if (sig.Length >= 2 && sig[0] == 0xFF && (sig[1] & 0xE0) == 0xE0) return ".mp3";
        if (sig.Length >= 4 && sig[0] == (byte)'O' && sig[1] == (byte)'g' && sig[2] == (byte)'g' && sig[3] == (byte)'S') return ".ogg";
        if (sig.Length >= 8 && sig[0] == (byte)'R' && sig[1] == (byte)'I' && sig[2] == (byte)'F' && sig[3] == (byte)'F'
            && sig[8] == (byte)'W' && sig[9] == (byte)'A' && sig[10] == (byte)'V' && sig[11] == (byte)'E') return ".wav";
        if (sig.Length >= 12 && sig[4] == (byte)'f' && sig[5] == (byte)'t' && sig[6] == (byte)'y' && sig[7] == (byte)'p') return ".m4a";
        if (sig.Length >= 4 && sig[0] == 0x1A && sig[1] == 0x45 && sig[2] == 0xDF && sig[3] == 0xA3) return ".webm";
        if (sig.Length >= 2 && sig[0] == 0xFF && sig[1] == 0xF1) return ".aac";

        return null;
    }

    public static string? DetectImportExt(Stream s)
    {
        var sig = ReadBytes(s, 5);
        if (sig == null) return null;

        if (sig.Length >= 4 && sig[0] == (byte)'%' && sig[1] == (byte)'P' && sig[2] == (byte)'D' && sig[3] == (byte)'F') return ".pdf";
        if (sig.Length >= 4 && sig[0] == 0x50 && sig[1] == 0x4B && sig[2] == 0x03 && sig[3] == 0x04) return ".zip"; // xlsx/docx
        return null;
    }

    private static byte[]? ReadBytes(Stream s, int count)
    {
        var buffer = new byte[count];
        int read = 0;
        while (read < count)
        {
            var n = s.Read(buffer, read, count - read);
            if (n == 0) break;
            read += n;
        }
        if (read == 0) return null;
        var result = new byte[read];
        Array.Copy(buffer, result, read);
        return result;
    }
}
