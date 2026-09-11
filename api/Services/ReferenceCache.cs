using System.Collections.Concurrent;
using FormUpAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Services;

/// <summary>
/// G1-8: cache proses untuk tabel referensi yang praktis statis
/// (FormStatus, ResponseStatus). Menghemat 1-3 query per request panas
/// (submit, exam-events, sync) tanpa mengubah kontrak apa pun.
/// </summary>
public static class ReferenceCache
{
    private static readonly ConcurrentDictionary<string, int> _formStatusIds = new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentDictionary<string, int> _responseStatusIds = new(StringComparer.OrdinalIgnoreCase);

    public static async Task<int> GetFormStatusIdAsync(FormUpDbContext db, string status, CancellationToken ct = default)
    {
        if (_formStatusIds.TryGetValue(status, out var id))
            return id;
        id = await db.FormStatuses
            .AsNoTracking()
            .Where(s => s.Status == status)
            .Select(s => s.Id)
            .FirstAsync(ct);
        _formStatusIds[status] = id;
        return id;
    }

    public static async Task<int?> GetResponseStatusIdAsync(FormUpDbContext db, string status, CancellationToken ct = default)
    {
        if (_responseStatusIds.TryGetValue(status, out var id))
            return id;
        var found = await db.ResponseStatuses
            .AsNoTracking()
            .Where(s => s.Status == status)
            .Select(s => (int?)s.Id)
            .FirstOrDefaultAsync(ct);
        if (found.HasValue)
            _responseStatusIds[status] = found.Value;
        return found;
    }

    /// Dipanggil bila seed referensi berubah (mis. migrasi manual).
    public static void Clear()
    {
        _formStatusIds.Clear();
        _responseStatusIds.Clear();
    }
}
