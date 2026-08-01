using System.Globalization;
using System.Security.Claims;
using ClosedXML.Excel;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using FormUpAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UglyToad.PdfPig;

namespace FormUpAPI.Controllers;

[Route("api/forms/{formId}/questions")]
[ApiController]
[Authorize]
public class QuestionsController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public QuestionsController(FormUpDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<object>>> GetAll(int formId)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions.OrderBy(o => o.OptionOrder))
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .OrderBy(q => q.QuestionOrder)
            .ToListAsync();

        return Ok(new ApiResponse<object>(200, "OK", questions.Select(MapQuestion).ToList()));
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<object>>> Create(int formId, [FromBody] SaveQuestionsRequest request)
    {
        if (request.Questions.Count == 0)
            return BadRequest(new ApiResponse<object>(400, "No questions provided"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var typeIds = request.Questions.Select(q => q.TypeId).Distinct().ToList();
        var validTypes = await _db.QuestionTypes
            .Where(t => typeIds.Contains(t.Id))
            .Select(t => t.Id)
            .ToListAsync();

        var invalidTypes = typeIds.Except(validTypes).ToList();
        if (invalidTypes.Count > 0)
            return BadRequest(new ApiResponse<object>(400, $"Invalid type IDs: {string.Join(", ", invalidTypes)}"));

        var maxOrder = await _db.Questions
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .MaxAsync(q => (int?)q.QuestionOrder) ?? 0;

        var createdIds = new List<int>();

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            foreach (var item in request.Questions)
            {
                if (string.IsNullOrWhiteSpace(item.Question))
                    continue;

                maxOrder++;
                var question = new Question
                {
                    FormId = formId,
                    TypeId = item.TypeId,
                    Question1 = item.Question,
                    QuestionOrder = item.QuestionOrder ?? maxOrder,
                    QuestionImage = item.QuestionImage,
                    QuestionAudio = item.QuestionAudio,
                    IsRequired = item.IsRequired ?? false,
                    CorrectAnswer = item.CorrectAnswer,
                    RandomizeOptions = item.RandomizeOptions ?? false,
                    CreatedAt = JakartaTime.Now,
                };

                _db.Questions.Add(question);
                await _db.SaveChangesAsync();
                createdIds.Add(question.Id);

                if (item.Options?.Count > 0)
                {
                    var options = item.Options.Select((o, i) => new OptionQuestion
                    {
                        QuestionId = question.Id,
                        OptionText = o.OptionText,
                        IsCorrect = o.IsCorrect ?? false,
                        OptionOrder = i + 1,
                        CreatedAt = JakartaTime.Now,
                    }).ToList();

                    _db.OptionQuestions.AddRange(options);
                }
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions.OrderBy(o => o.OptionOrder))
            .Where(q => createdIds.Contains(q.Id))
            .OrderBy(q => q.QuestionOrder)
            .ToListAsync();

        return CreatedAtAction(nameof(Create), new ApiResponse<object>(201, $"{questions.Count} questions created", questions.Select(MapQuestion).ToList()));
    }

    [HttpPut]
    public async Task<ActionResult<ApiResponse<object>>> Save(int formId, [FromBody] SaveQuestionsRequest request)
    {
        if (request.Questions.Count == 0)
            return BadRequest(new ApiResponse<object>(400, "No questions provided"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var typeIds = request.Questions.Select(q => q.TypeId).Distinct().ToList();
        var validTypes = await _db.QuestionTypes
            .Where(t => typeIds.Contains(t.Id))
            .Select(t => t.Id)
            .ToListAsync();

        var invalidTypes = typeIds.Except(validTypes).ToList();
        if (invalidTypes.Count > 0)
            return BadRequest(new ApiResponse<object>(400, $"Invalid type IDs: {string.Join(", ", invalidTypes)}"));

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            var oldQuestionIds = await _db.Questions
                .Where(q => q.FormId == formId && q.DeletedAt == null)
                .Select(q => q.Id)
                .ToListAsync();

            if (oldQuestionIds.Count > 0)
            {
                await _db.OptionQuestions
                    .Where(o => oldQuestionIds.Contains(o.QuestionId))
                    .ExecuteDeleteAsync();

                await _db.Questions
                    .Where(q => oldQuestionIds.Contains(q.Id))
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(q => q.DeletedAt, JakartaTime.Now)
                        .SetProperty(q => q.UpdatedAt, JakartaTime.Now));
            }

            var createdIds = new List<int>();
            var order = 0;

            foreach (var item in request.Questions)
            {
                if (string.IsNullOrWhiteSpace(item.Question))
                    continue;

                order++;
                var question = new Question
                {
                    FormId = formId,
                    TypeId = item.TypeId,
                    Question1 = item.Question,
                    QuestionOrder = item.QuestionOrder ?? order,
                    QuestionImage = item.QuestionImage,
                    QuestionAudio = item.QuestionAudio,
                    IsRequired = item.IsRequired ?? false,
                    CorrectAnswer = item.CorrectAnswer,
                    RandomizeOptions = item.RandomizeOptions ?? false,
                    CreatedAt = JakartaTime.Now,
                };

                _db.Questions.Add(question);
                await _db.SaveChangesAsync();
                createdIds.Add(question.Id);

                if (item.Options?.Count > 0)
                {
                    var options = item.Options.Select((o, i) => new OptionQuestion
                    {
                        QuestionId = question.Id,
                        OptionText = o.OptionText,
                        IsCorrect = o.IsCorrect ?? false,
                        OptionOrder = i + 1,
                        CreatedAt = JakartaTime.Now,
                    }).ToList();

                    _db.OptionQuestions.AddRange(options);
                }
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            var questions = await _db.Questions
                .Include(q => q.OptionQuestions.OrderBy(o => o.OptionOrder))
                .Where(q => createdIds.Contains(q.Id))
                .OrderBy(q => q.QuestionOrder)
                .ToListAsync();

            return Ok(new ApiResponse<object>(200, $"{questions.Count} questions updated", questions.Select(MapQuestion).ToList()));
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }

    [HttpPost("import")]
    public async Task<ActionResult<ApiResponse<object>>> Import(int formId, IFormFile? file)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new ApiResponse<object>(400, "No file uploaded"));

        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new ApiResponse<object>(400, "File size must be under 5 MB"));

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowedExts = new[] { ".xlsx", ".xls", ".csv", ".pdf", ".docx" };
        if (!allowedExts.Contains(ext))
            return BadRequest(new ApiResponse<object>(400, "Only .xlsx, .xls, .csv, .pdf, and .docx files are allowed"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        using var stream = new MemoryStream();
        await file.CopyToAsync(stream);
        stream.Position = 0;

        List<ImportRow> rows;

        try
        {
            rows = ext switch
            {
                ".csv" => ParseCsv(stream),
                ".pdf" => ParsePdf(stream),
                ".docx" => ParseDocx(stream),
                _ => ParseExcel(stream),
            };
        }
        catch (Exception ex)
        {
            return BadRequest(new ApiResponse<object>(400, $"Failed to parse file: {ex.Message}"));
        }

        if (rows.Count == 0)
            return BadRequest(new ApiResponse<object>(400, "No valid questions found in file"));

        var result = new ImportQuestionsResult();
        var maxOrder = await _db.Questions
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .MaxAsync(q => (int?)q.QuestionOrder) ?? 0;

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            foreach (var row in rows)
            {
                if (string.IsNullOrWhiteSpace(row.Question))
                {
                    result.TotalSkipped++;
                    result.Errors.Add($"Row {row.RowNumber}: empty question text");
                    continue;
                }

                var typeExists = await _db.QuestionTypes.AnyAsync(t => t.Id == row.TypeId);
                if (!typeExists)
                {
                    result.TotalSkipped++;
                    result.Errors.Add($"Row {row.RowNumber}: invalid type_id {row.TypeId}");
                    continue;
                }

                var question = new Question
                {
                    FormId = formId,
                    TypeId = row.TypeId,
                    Question1 = row.Question,
                    QuestionOrder = row.Order ?? ++maxOrder,
                    IsRequired = row.IsRequired,
                    CorrectAnswer = row.CorrectAnswer,
                    RandomizeOptions = row.RandomizeOptions,
                    CreatedAt = JakartaTime.Now,
                };

                _db.Questions.Add(question);
                await _db.SaveChangesAsync();

                if (row.Options.Count > 0)
                {
                    var options = row.Options.Select((opt, i) => new OptionQuestion
                    {
                        QuestionId = question.Id,
                        OptionText = opt,
                        OptionOrder = i + 1,
                        CreatedAt = JakartaTime.Now,
                    }).ToList();

                    _db.OptionQuestions.AddRange(options);
                }

                result.TotalImported++;
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }

        return Ok(new ApiResponse<object>(200, $"{result.TotalImported} questions imported", result));
    }

    [HttpPost("{id}/upload-audio")]
    public async Task<ActionResult<ApiResponse<object>>> UploadAudio(int formId, int id, IFormFile? file)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new ApiResponse<object>(400, "No file uploaded"));

        var allowedExts = new[] { ".mp3", ".wav", ".ogg", ".m4a", ".aac", ".webm" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowedTypes = new[] { "audio/mpeg", "audio/wav", "audio/ogg", "audio/mp4", "audio/aac", "audio/webm" };

        if (!allowedExts.Contains(ext))
            return BadRequest(new ApiResponse<object>(400, "Only MP3, WAV, OGG, M4A, AAC, and WebM audio files are allowed"));

        if (!allowedTypes.Contains(file.ContentType))
            return BadRequest(new ApiResponse<object>(400, "Invalid file type"));

        if (file.Length > 20 * 1024 * 1024)
            return BadRequest(new ApiResponse<object>(400, "File size must be under 20 MB"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var question = await _db.Questions
            .FirstOrDefaultAsync(q => q.Id == id && q.FormId == formId && q.DeletedAt == null);

        if (question == null)
            return NotFound(new ApiResponse<object>(404, "Question not found"));

        var uniqueName = $"{Guid.NewGuid()}{ext}";
        var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "questions", "audio");
        Directory.CreateDirectory(uploadDir);
        var filePath = Path.Combine(uploadDir, uniqueName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        if (!string.IsNullOrEmpty(question.QuestionAudio))
        {
            var oldPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", question.QuestionAudio.TrimStart('/'));
            if (System.IO.File.Exists(oldPath))
                System.IO.File.Delete(oldPath);
        }

        question.QuestionAudio = $"/questions/audio/{uniqueName}";
        question.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Audio uploaded", new { questionAudio = question.QuestionAudio }));
    }

    [HttpPost("{id}/upload-image")]
    public async Task<ActionResult<ApiResponse<object>>> UploadImage(int formId, int id, IFormFile? file)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new ApiResponse<object>(400, "No file uploaded"));

        var allowedExts = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowedTypes = new[] { "image/jpeg", "image/png", "image/gif", "image/webp" };

        if (!allowedExts.Contains(ext))
            return BadRequest(new ApiResponse<object>(400, "Only JPG, PNG, GIF, and WebP files are allowed"));

        if (!allowedTypes.Contains(file.ContentType))
            return BadRequest(new ApiResponse<object>(400, "Invalid file type"));

        if (file.Length > 10 * 1024 * 1024)
            return BadRequest(new ApiResponse<object>(400, "File size must be under 10 MB"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var question = await _db.Questions
            .FirstOrDefaultAsync(q => q.Id == id && q.FormId == formId && q.DeletedAt == null);

        if (question == null)
            return NotFound(new ApiResponse<object>(404, "Question not found"));

        var uniqueName = $"{Guid.NewGuid()}{ext}";
        var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "questions", "images");
        Directory.CreateDirectory(uploadDir);
        var filePath = Path.Combine(uploadDir, uniqueName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        if (!string.IsNullOrEmpty(question.QuestionImage))
        {
            var oldPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", question.QuestionImage.TrimStart('/'));
            if (System.IO.File.Exists(oldPath))
                System.IO.File.Delete(oldPath);
        }

        question.QuestionImage = $"/questions/images/{uniqueName}";
        question.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Image uploaded", new { questionImage = question.QuestionImage }));
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }

    private static QuestionResponse MapQuestion(Question q) => new()
    {
        Id = q.Id,
        FormId = q.FormId,
        TypeId = q.TypeId,
        Question = q.Question1,
        QuestionOrder = q.QuestionOrder,
        QuestionImage = q.QuestionImage,
        QuestionAudio = q.QuestionAudio,
        IsRequired = q.IsRequired,
        CorrectAnswer = q.CorrectAnswer,
        RandomizeOptions = q.RandomizeOptions,
        Options = (q.OptionQuestions ?? []).OrderBy(o => o.OptionOrder).Select(o => new OptionResponse
        {
            Id = o.Id,
            OptionText = o.OptionText ?? "",
            OptionImage = o.OptionImage,
            IsCorrect = o.IsCorrect,
            OptionOrder = o.OptionOrder,
        }).ToList(),
        CreatedAt = q.CreatedAt,
        UpdatedAt = q.UpdatedAt,
    };

    private static List<ImportRow> ParseExcel(Stream stream)
    {
        using var workbook = new XLWorkbook(stream);
        var sheet = workbook.Worksheet(1);
        var rows = new List<ImportRow>();

        var headerRow = sheet.Row(1);
        var colMap = new Dictionary<string, int>();
        foreach (var cell in headerRow.CellsUsed())
        {
            var key = cell.GetString().Trim().ToLowerInvariant();
            colMap[key] = cell.Address.ColumnNumber;
        }

        foreach (var row in sheet.RowsUsed().Skip(1))
        {
            var importRow = new ImportRow { RowNumber = row.RowNumber() };

            if (colMap.TryGetValue("question", out var qCol))
                importRow.Question = row.Cell(qCol).GetString().Trim();

            if (colMap.TryGetValue("type_id", out var tCol))
            {
                var val = row.Cell(tCol).GetString().Trim();
                if (int.TryParse(val, out var typeId))
                    importRow.TypeId = typeId;
            }

            if (colMap.TryGetValue("order", out var oCol))
            {
                var val = row.Cell(oCol).GetString().Trim();
                if (int.TryParse(val, out var order))
                    importRow.Order = order;
            }

            if (colMap.TryGetValue("is_required", out var rCol))
            {
                var val = row.Cell(rCol).GetString().Trim().ToLowerInvariant();
                importRow.IsRequired = val is "true" or "1" or "yes";
            }

            if (colMap.TryGetValue("randomize_options", out var randCol))
            {
                var val = row.Cell(randCol).GetString().Trim().ToLowerInvariant();
                importRow.RandomizeOptions = val is "true" or "1" or "yes";
            }

            if (colMap.TryGetValue("correct_answer", out var caCol))
                importRow.CorrectAnswer = row.Cell(caCol).GetString().Trim();

            if (colMap.TryGetValue("options", out var optCol))
            {
                var raw = row.Cell(optCol).GetString().Trim();
                importRow.Options = raw.Split('|', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).ToList();
            }

            rows.Add(importRow);
        }

        return rows;
    }

    private static List<ImportRow> ParseCsv(Stream stream)
    {
        using var reader = new StreamReader(stream);
        var rows = new List<ImportRow>();

        var headerLine = reader.ReadLine();
        if (headerLine == null) return rows;

        var headers = headerLine.Split(',').Select(h => h.Trim().ToLowerInvariant()).ToList();
        var colMap = headers.Select((h, i) => new { h, i }).ToDictionary(x => x.h, x => x.i);

        var lineNum = 1;
        while (!reader.EndOfStream)
        {
            lineNum++;
            var line = reader.ReadLine();
            if (string.IsNullOrWhiteSpace(line)) continue;

            var values = ParseCsvLine(line);
            var importRow = new ImportRow { RowNumber = lineNum };

            if (colMap.TryGetValue("question", out var qIdx) && qIdx < values.Count)
                importRow.Question = values[qIdx].Trim();

            if (colMap.TryGetValue("type_id", out var tIdx) && tIdx < values.Count)
            {
                if (int.TryParse(values[tIdx].Trim(), out var typeId))
                    importRow.TypeId = typeId;
            }

            if (colMap.TryGetValue("order", out var oIdx) && oIdx < values.Count)
            {
                if (int.TryParse(values[oIdx].Trim(), out var order))
                    importRow.Order = order;
            }

            if (colMap.TryGetValue("is_required", out var rIdx) && rIdx < values.Count)
            {
                var val = values[rIdx].Trim().ToLowerInvariant();
                importRow.IsRequired = val is "true" or "1" or "yes";
            }

            if (colMap.TryGetValue("randomize_options", out var randIdx) && randIdx < values.Count)
            {
                var val = values[randIdx].Trim().ToLowerInvariant();
                importRow.RandomizeOptions = val is "true" or "1" or "yes";
            }

            if (colMap.TryGetValue("correct_answer", out var caIdx) && caIdx < values.Count)
                importRow.CorrectAnswer = values[caIdx].Trim();

            if (colMap.TryGetValue("options", out var optIdx) && optIdx < values.Count)
            {
                importRow.Options = values[optIdx].Trim().Split('|', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).ToList();
            }

            rows.Add(importRow);
        }

        return rows;
    }

    private static List<ImportRow> ParseDocx(Stream stream)
    {
        using var doc = WordprocessingDocument.Open(stream, false);
        var body = doc.MainDocumentPart?.Document;;
        if (body == null) return [];

        var paragraphs = body.Elements<Paragraph>()
            .Select(p => p.InnerText.Trim())
            .Where(t => t.Length > 0)
            .ToList();

        return ParseStructuredText(paragraphs);
    }

    private static List<ImportRow> ParsePdf(Stream stream)
    {
        using var pdf = PdfDocument.Open(stream);
        var lines = new List<string>();

        foreach (var page in pdf.GetPages())
        {
            var text = page.Text;
            foreach (var line in text.Split('\n', StringSplitOptions.RemoveEmptyEntries))
            {
                var trimmed = line.Trim();
                if (trimmed.Length > 0)
                    lines.Add(trimmed);
            }
        }

        return ParseStructuredText(lines);
    }

    private static List<ImportRow> ParseStructuredText(List<string> lines)
    {
        var rows = new List<ImportRow>();
        ImportRow? current = null;
        var rowNum = 0;

        foreach (var line in lines)
        {
            var lower = line.ToLowerInvariant();

            if (lower.StartsWith("question:"))
            {
                if (current != null)
                    rows.Add(current);

                current = new ImportRow { RowNumber = ++rowNum };
                current.Question = line[9..].Trim();
            }
            else if (lower.StartsWith("type_id:") && int.TryParse(line[8..].Trim(), out var typeId))
            {
                if (current == null) continue;
                current.TypeId = typeId;
            }
            else if (lower.StartsWith("is_required:") && current != null)
            {
                current.IsRequired = line[12..].Trim() is "true" or "yes" or "1";
            }
            else if (lower.StartsWith("randomize_options:") && current != null)
            {
                current.RandomizeOptions = line[18..].Trim() is "true" or "yes" or "1";
            }
            else if (lower.StartsWith("correct_answer:") && current != null)
            {
                current.CorrectAnswer = line[15..].Trim();
            }
            else if (lower.StartsWith("options:") && current != null)
            {
                current.Options = line[8..].Trim().Split('|', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).ToList();
            }
            else if (line.StartsWith("- ") || line.StartsWith("• "))
            {
                if (current == null) continue;
                current.Options.Add(line[2..].Trim());
            }
            else if (current == null)
            {
                current = new ImportRow { RowNumber = ++rowNum };
                current.Question = line;
            }
        }

        if (current != null)
            rows.Add(current);

        return rows;
    }

    private static List<string> ParseCsvLine(string line)
    {
        var values = new List<string>();
        var current = new System.Text.StringBuilder();
        var inQuotes = false;

        foreach (var ch in line)
        {
            if (ch == '"')
            {
                inQuotes = !inQuotes;
            }
            else if (ch == ',' && !inQuotes)
            {
                values.Add(current.ToString());
                current.Clear();
            }
            else
            {
                current.Append(ch);
            }
        }

        values.Add(current.ToString());
        return values;
    }
}

public class ImportRow
{
    public int RowNumber { get; set; }
    public string? Question { get; set; }
    public int TypeId { get; set; } = 1;
    public int? Order { get; set; }
    public bool IsRequired { get; set; }
    public bool RandomizeOptions { get; set; }
    public string? CorrectAnswer { get; set; }
    public List<string> Options { get; set; } = new();
}
