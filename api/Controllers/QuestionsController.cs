using System.Globalization;
using System.Security.Claims;
using ClosedXML.Excel;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using FormUpAPI.Models;
using FormUpAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using UglyToad.PdfPig;

namespace FormUpAPI.Controllers;

[Route("api/forms/{formId}/questions")]
[ApiController]
[EnableRateLimiting("creator")]
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
            .Include(f => f.Status)
            .FirstOrDefaultAsync(f => f.Id == formId && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        // Pemilik form atau admin boleh melihat soal
        if (form.UserId != user.Id && user.Role != "ADMIN")
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

        using var tx = await _db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        await LockFormRow(formId);

        var blocked = await EnsureNoResponses(formId);
        if (blocked != null)
            return blocked;

        var maxOrder = await _db.Questions
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .MaxAsync(q => (int?)q.QuestionOrder) ?? 0;

        var createdIds = new List<int>();

        try
        {
            foreach (var item in request.Questions)
            {
                if (string.IsNullOrWhiteSpace(item.Question))
                    continue;

                if (!RichTextValidation.TryValidate(item.Question, out var formatError))
                    return BadRequest(new ApiResponse<object>(400, formatError ?? "Konten pertanyaan tidak valid"));

                maxOrder++;
                var question = new Question
                {
                    FormId = formId,
                    TypeId = item.TypeId,
                    Question1 = item.Question,
                    QuestionFormat = RichTextValidation.FormatOf(item.Question),
                    QuestionOrder = item.QuestionOrder ?? maxOrder,
                    QuestionImage = item.QuestionImage,
                    QuestionAudio = item.QuestionAudio,
                    IsRequired = item.IsRequired ?? false,
                    CorrectAnswer = item.CorrectAnswer,
                    RandomizeOptions = item.RandomizeOptions ?? false,
                    CreatedAt = DateTime.UtcNow,
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
                        CreatedAt = DateTime.UtcNow,
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

        return CreatedAtAction(nameof(GetAll), new { formId }, new ApiResponse<object>(201, $"{questions.Count} questions created", questions.Select(MapQuestion).ToList()));
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

        using var tx = await _db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        await LockFormRow(formId);

        var blocked = await EnsureNoResponses(formId);
        if (blocked != null)
            return blocked;

        try
        {
            var existingQuestions = await _db.Questions
                .Include(q => q.OptionQuestions)
                .Where(q => q.FormId == formId && q.DeletedAt == null)
                .ToListAsync();

            var existingById = existingQuestions.ToDictionary(q => q.Id);
            var nextOrder = existingQuestions.Count > 0 ? existingQuestions.Max(q => q.QuestionOrder) : 0;
            var submittedIds = request.Questions
                .Where(q => q.Id.HasValue && existingById.ContainsKey(q.Id.Value))
                .Select(q => q.Id!.Value)
                .ToHashSet();

            foreach (var item in request.Questions)
            {
                var questionText = item.Question ?? "";
                if (!string.IsNullOrWhiteSpace(questionText) && !RichTextValidation.TryValidate(questionText, out var formatError))
                    return BadRequest(new ApiResponse<object>(400, formatError ?? "Konten pertanyaan tidak valid"));

                Question question;
                if (item.Id.HasValue && existingById.TryGetValue(item.Id.Value, out var existing))
                {
                    question = existing;
                    question.TypeId = item.TypeId;
                    question.Question1 = questionText;
                    question.QuestionFormat = RichTextValidation.FormatOf(questionText);
                    question.QuestionOrder = item.QuestionOrder ?? question.QuestionOrder;
                    question.QuestionImage = item.QuestionImage;
                    question.QuestionAudio = item.QuestionAudio;
                    question.IsRequired = item.IsRequired ?? false;
                    question.CorrectAnswer = item.CorrectAnswer;
                    question.RandomizeOptions = item.RandomizeOptions ?? false;
                    question.Points = item.Points;
                    question.UpdatedAt = DateTime.UtcNow;
                }
                else
                {
                    question = new Question
                    {
                        FormId = formId,
                        TypeId = item.TypeId,
                        Question1 = questionText,
                        QuestionFormat = RichTextValidation.FormatOf(questionText),
                        QuestionOrder = item.QuestionOrder ?? ++nextOrder,
                        QuestionImage = item.QuestionImage,
                        QuestionAudio = item.QuestionAudio,
                        IsRequired = item.IsRequired ?? false,
                        CorrectAnswer = item.CorrectAnswer,
                        RandomizeOptions = item.RandomizeOptions ?? false,
                        Points = item.Points,
                        CreatedAt = DateTime.UtcNow,
                    };

                    _db.Questions.Add(question);
                    await _db.SaveChangesAsync();
                }

                if (question.OptionQuestions.Count > 0)
                {
                    _db.OptionQuestions.RemoveRange(question.OptionQuestions);
                    question.OptionQuestions.Clear();
                }

                if (item.Options?.Count > 0)
                {
                    var options = item.Options.Select((o, i) => new OptionQuestion
                    {
                        QuestionId = question.Id,
                        OptionText = o.OptionText,
                        IsCorrect = o.IsCorrect ?? false,
                        OptionOrder = i + 1,
                        CreatedAt = DateTime.UtcNow,
                    }).ToList();

                    _db.OptionQuestions.AddRange(options);
                }

                await _db.SaveChangesAsync();
            }

            var removedIds = existingQuestions
                .Where(q => !submittedIds.Contains(q.Id))
                .Select(q => q.Id)
                .ToList();

            if (removedIds.Count > 0)
            {
                await _db.OptionQuestions
                    .Where(o => removedIds.Contains(o.QuestionId))
                    .ExecuteDeleteAsync();

                await _db.Questions
                    .Where(q => removedIds.Contains(q.Id))
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(q => q.DeletedAt, DateTime.UtcNow)
                        .SetProperty(q => q.UpdatedAt, DateTime.UtcNow));
            }

            // Form published yang kehabisan soal otomatis kembali jadi draft
            await UnpublishIfNoQuestions(form);

            await tx.CommitAsync();

            var questions = await _db.Questions
                .Include(q => q.OptionQuestions.OrderBy(o => o.OptionOrder))
                .Where(q => q.FormId == formId && q.DeletedAt == null)
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

    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(int formId, int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        using var tx = await _db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        await LockFormRow(formId);

        var blocked = await EnsureNoResponses(formId);
        if (blocked != null)
            return blocked;

        var question = await _db.Questions
            .FirstOrDefaultAsync(q => q.Id == id && q.FormId == formId && q.DeletedAt == null);

        if (question == null)
            return NotFound(new ApiResponse<object>(404, "Question not found"));

        await _db.OptionQuestions
            .Where(o => o.QuestionId == id)
            .ExecuteDeleteAsync();

        question.DeletedAt = DateTime.UtcNow;
        question.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        // Form published yang kehabisan soal otomatis kembali jadi draft
        await UnpublishIfNoQuestions(form);

        await tx.CommitAsync();

        return Ok(new ApiResponse<object>(200, "Question deleted"));
    }

    /// <summary>
    /// Parse file impor: validasi tipe/ukuran, deteksi ekstensi via konten,
    /// lalu parse ke baris soal. TIDAK menyentuh database.
    /// </summary>
    private static async Task<(ActionResult? Error, List<ImportRow>? Rows)> ParseImportFile(IFormFile? file)
    {
        if (file == null || file.Length == 0)
            return (new BadRequestObjectResult(new ApiResponse<object>(400, "No file uploaded")), null);

        if (file.Length > FileValidation.MaxImportBytes)
            return (new BadRequestObjectResult(new ApiResponse<object>(400, "File size must be under 5 MB")), null);

        using var stream = new MemoryStream();
        await file.CopyToAsync(stream);

        // Deteksi tipe dari ISI file — nama file sering tidak andal
        // (Google Drive bisa menyimpan "soal" tanpa ekstensi atau "soal.docx.docx").
        stream.Position = 0;
        var contentExt = FileValidation.DetectImportExt(stream);
        var originalExt = Path.GetExtension(file.FileName).ToLowerInvariant();
        string ext;
        if (contentExt == ".pdf")
        {
            ext = ".pdf";
        }
        else if (contentExt == ".zip")
        {
            // ZIP = docx/xlsx. Bedakan dari struktur arsip, bukan nama file.
            stream.Position = 0;
            ext = FileValidation.DetectOfficeExt(stream) ?? "";
            if (ext == "")
            {
                ext = originalExt is ".xlsx" or ".xls" or ".docx" ? originalExt : "";
                if (ext == "")
                    return (new BadRequestObjectResult(new ApiResponse<object>(400,
                        "Isi file bukan dokumen Word/Excel yang valid.")), null);
            }
        }
        else if (originalExt == ".csv")
        {
            ext = ".csv";
        }
        else
        {
            return (new BadRequestObjectResult(new ApiResponse<object>(400,
                "Only .xlsx, .xls, .csv, .pdf, and .docx files are allowed")), null);
        }

        List<ImportRow> rows;

        try
        {
            stream.Position = 0; // penting: deteksi signature menggeser posisi stream
            rows = ext switch
            {
                ".csv" => ParseCsv(stream),
                ".pdf" => ParseStructuredEntries(ParsePdfEntries(stream)),
                ".docx" => ParseStructuredEntries(ParseDocxEntries(stream)),
                _ => ParseExcel(stream),
            };
        }
        catch (Exception)
        {
            return (new BadRequestObjectResult(new ApiResponse<object>(400,
                "File tidak dapat dibaca. Pastikan format file sesuai template.")), null);
        }

        if (rows.Count == 0)
            return (new BadRequestObjectResult(new ApiResponse<object>(400,
                "Tidak ada baris soal yang terbaca dari file. Pastikan isi file sesuai template.")), null);

        // Semua baris kosong → hampir pasti header kolom tidak sesuai template.
        // Beri pesan spesifik daripada "empty question text" per baris.
        if (rows.All(r => string.IsNullOrWhiteSpace(r.Question)))
            return (new BadRequestObjectResult(new ApiResponse<object>(400,
                "Kolom 'question' tidak ditemukan. Pastikan baris pertama file berisi header sesuai template (question,type_id,...).")), null);

        return (null, rows);
    }

    [HttpPost("import/preview")]
    public async Task<ActionResult<ApiResponse<object>>> PreviewImport(int formId, IFormFile? file)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var parsed = await ParseImportFile(file);
        if (parsed.Error != null) return parsed.Error;
        var rows = parsed.Rows!;

        var validTypeIds = await _db.QuestionTypes.Select(t => t.Id).ToListAsync();
        var errors = ValidateImportRows(rows, validTypeIds);

        var invalidKeys = errors
            .Select(e => e.RowNumber)
            .ToHashSet();
        var validRows = rows
            .Where(r => !invalidKeys.Contains(r.RowNumber))
            .ToList();

        // Nomor soal hasil impor lanjut setelah semua soal yang sudah ada
        var existingMax = await _db.Questions
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .MaxAsync(q => (int?)q.QuestionOrder) ?? 0;

        var blocked = await _db.Responses.AnyAsync(r => r.FormId == formId);

        var nextAuto = existingMax;
        return Ok(new ApiResponse<object>(200, "Preview ready", new
        {
            preview = true,
            blocked,
            totalRows = rows.Count,
            totalQuestions = validRows.Count,
            skippedCount = rows.Count - validRows.Count,
            canImport = !blocked && validRows.Count > 0,
            startNumber = existingMax + 1,
            errors = errors.Select(e => new { rowNumber = e.RowNumber, field = e.Field, message = e.Message }).ToList(),
            questions = validRows.Take(100).Select((r, i) => new
            {
                // Proyeksi nomor final: kolom `order` file di-offset setelah soal lama
                order = r.Order.HasValue ? existingMax + r.Order.Value : ++nextAuto,
                rowNumber = r.RowNumber,
                question = r.Question,
                typeId = r.TypeId,
                isRequired = r.IsRequired,
                optionsCount = r.Options.Count,
                // Teks tiap opsi agar client bisa menampilkan & memverifikasinya
                options = r.Options,
                hasCorrectAnswer = !string.IsNullOrEmpty(r.CorrectAnswer),
                hasImage = r.ImageBytes != null,
                // Gambar langsung dalam bentuk data URI base64 agar client
                // (mobile/web) bisa menampilkannya tanpa request tambahan.
                image = ToImageDataUri(r.ImageBytes, r.ImageExt),
            }),
        }));
    }

    [HttpPost("import")]
    public async Task<ActionResult<ApiResponse<object>>> Import(int formId, IFormFile? file)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var parsed = await ParseImportFile(file);
        if (parsed.Error != null) return parsed.Error;
        var rows = parsed.Rows!;

        var validTypeIds = await _db.QuestionTypes
            .Select(t => t.Id)
            .ToListAsync();
        var errors = ValidateImportRows(rows, validTypeIds);

        var invalidKeys = errors
            .Select(e => e.RowNumber)
            .ToHashSet();
        var validRows = rows
            .Where(r => !invalidKeys.Contains(r.RowNumber))
            .ToList();

        var result = new ImportQuestionsResult
        {
            TotalSkipped = rows.Count - validRows.Count,
            Errors = errors.Select(FormatImportError).ToList(),
        };

        if (validRows.Count == 0)
            return BadRequest(new ApiResponse<object>(400, "Tidak ada soal valid yang bisa diimpor dari file", result));

        using var tx = await _db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        await LockFormRow(formId);

        var blocked = await EnsureNoResponses(formId);
        if (blocked != null)
            return blocked;

        var maxOrder = await _db.Questions
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .MaxAsync(q => (int?)q.QuestionOrder) ?? 0;

        try
        {
            foreach (var row in validRows)
            {
                var question = new Question
                {
                    FormId = formId,
                    TypeId = row.TypeId,
                    // Question1 sudah divalidasi non-kosong oleh ValidateImportRows
                    Question1 = row.Question!,
                    QuestionFormat = RichTextValidation.Text,
                    // Kolom `order` file bersifat relatif: di-offset setelah
                    // soal yang sudah ada agar tidak menimpa nomor lama.
                    QuestionOrder = row.Order.HasValue ? maxOrder + row.Order.Value : ++maxOrder,
                    IsRequired = row.IsRequired,
                    CorrectAnswer = row.CorrectAnswer,
                    RandomizeOptions = row.RandomizeOptions,
                    CreatedAt = DateTime.UtcNow,
                };

                // Simpan gambar hasil ekstraksi dokumen (jika ada)
                if (row.ImageBytes is { Length: > 0 })
                {
                    var imgName = $"{Guid.NewGuid()}{row.ImageExt}";
                    var imgDir = Path.Combine(
                        Directory.GetCurrentDirectory(), "wwwroot", "questions", "images");
                    Directory.CreateDirectory(imgDir);
                    await System.IO.File.WriteAllBytesAsync(Path.Combine(imgDir, imgName), row.ImageBytes);
                    question.QuestionImage = $"/questions/images/{imgName}";
                }

                _db.Questions.Add(question);

                if (row.Options.Count > 0)
                {
                    // Pakai navigation property (bukan QuestionId) supaya EF Core
                    // mengisi FK otomatis setelah Id soal ter-generate saat SaveChanges.
                    var options = row.Options.Select((opt, i) =>
                    {
                        var cleanOpt = opt.Trim();
                        var isCorrect = false;
                        if (!string.IsNullOrWhiteSpace(row.CorrectAnswer))
                        {
                            var ca = row.CorrectAnswer.Trim();
                            if (string.Equals(cleanOpt, ca, StringComparison.OrdinalIgnoreCase))
                                isCorrect = true;
                            else if (cleanOpt.Length > 3 && (cleanOpt[1] == '.' || cleanOpt[1] == ')') &&
                                     string.Equals(cleanOpt[2..].Trim(), ca, StringComparison.OrdinalIgnoreCase))
                                isCorrect = true;
                            else if (ca.Length >= 1 && char.ToUpper(ca[0]) >= 'A' && char.ToUpper(ca[0]) - 'A' == i)
                                isCorrect = true;
                            else if (int.TryParse(ca, out var num) && num == i + 1)
                                isCorrect = true;
                        }

                        return new OptionQuestion
                        {
                            Question = question,
                            OptionText = cleanOpt,
                            OptionOrder = i + 1,
                            IsCorrect = isCorrect,
                            CreatedAt = DateTime.UtcNow,
                        };
                    }).ToList();

                    _db.OptionQuestions.AddRange(options);
                }

                await _db.SaveChangesAsync();

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

        if (file.Length > FileValidation.MaxAudioBytes)
            return BadRequest(new ApiResponse<object>(400, "File size must be under 20 MB"));

        using var ms = new MemoryStream();
        await file.CopyToAsync(ms);
        ms.Position = 0;

        var ext = FileValidation.DetectAudioExt(ms);
        if (ext == null)
            return BadRequest(new ApiResponse<object>(400, "Invalid audio file. Only MP3, WAV, OGG, M4A, AAC, and WebM are allowed"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var blocked = await EnsureNoResponses(formId);
        if (blocked != null)
            return blocked;

        var question = await _db.Questions
            .FirstOrDefaultAsync(q => q.Id == id && q.FormId == formId && q.DeletedAt == null);

        if (question == null)
            return NotFound(new ApiResponse<object>(404, "Question not found"));

        var uniqueName = $"{Guid.NewGuid()}{ext}";
        var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "questions", "audio");
        Directory.CreateDirectory(uploadDir);
        var filePath = Path.Combine(uploadDir, uniqueName);

        ms.Position = 0;
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await ms.CopyToAsync(stream);
        }

        if (!string.IsNullOrEmpty(question.QuestionAudio))
        {
            var oldPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", question.QuestionAudio.TrimStart('/'));
            if (System.IO.File.Exists(oldPath))
                System.IO.File.Delete(oldPath);
        }

        question.QuestionAudio = $"/questions/audio/{uniqueName}";
        question.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Audio uploaded", new { questionAudio = question.QuestionAudio }));
    }

    [HttpPost("{id}/upload-image")]
    public async Task<ActionResult<ApiResponse<object>>> UploadImage(int formId, int id, IFormFile? file)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new ApiResponse<object>(400, "No file uploaded"));

        if (file.Length > FileValidation.MaxImageBytes)
            return BadRequest(new ApiResponse<object>(400, "File size must be under 10 MB"));

        using var ms = new MemoryStream();
        await file.CopyToAsync(ms);
        ms.Position = 0;

        var ext = FileValidation.DetectImageExt(ms);
        if (ext == null)
            return BadRequest(new ApiResponse<object>(400, "Invalid image file. Only JPG, PNG, GIF, and WebP are allowed"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var blocked = await EnsureNoResponses(formId);
        if (blocked != null)
            return blocked;

        var question = await _db.Questions
            .FirstOrDefaultAsync(q => q.Id == id && q.FormId == formId && q.DeletedAt == null);

        if (question == null)
            return NotFound(new ApiResponse<object>(404, "Question not found"));

        var uniqueName = $"{Guid.NewGuid()}{ext}";
        var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "questions", "images");
        Directory.CreateDirectory(uploadDir);
        var filePath = Path.Combine(uploadDir, uniqueName);

        ms.Position = 0;
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await ms.CopyToAsync(stream);
        }

        if (!string.IsNullOrEmpty(question.QuestionImage))
        {
            var oldPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", question.QuestionImage.TrimStart('/'));
            if (System.IO.File.Exists(oldPath))
                System.IO.File.Delete(oldPath);
        }

        question.QuestionImage = $"/questions/images/{uniqueName}";
        question.UpdatedAt = DateTime.UtcNow;
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

    /// <summary>
    /// Kunci row Form (UPDLOCK) dalam transaksi serializable supaya edit soal
    /// dan submit respons tidak bisa saling menimpa di waktu bersamaan.
    /// </summary>
    private async Task LockFormRow(int formId)
    {
        await _db.Database.ExecuteSqlRawAsync(
            "SELECT [id] FROM [Form] WITH (UPDLOCK, ROWLOCK) WHERE [id] = {0}", formId);
    }

    /// <summary>
    /// Soal hanya boleh diedit jika form belum punya respon sama sekali.
    /// Dipanggil di DALAM transaksi setelah row form dikunci agar bebas race condition.
    /// </summary>
    private async Task<ActionResult?> EnsureNoResponses(int formId)
    {
        var hasResponse = await _db.Responses.AnyAsync(r => r.FormId == formId);
        if (hasResponse)
            return BadRequest(new ApiResponse<object>(400,
                "Soal tidak dapat diubah karena form sudah memiliki respons"));

        return null;
    }

    /// <summary>
    /// Aturan: form published yang kehabisan soal otomatis kembali jadi draft.
    /// Dipanggil di DALAM transaksi sebelum commit.
    /// </summary>
    private async Task UnpublishIfNoQuestions(Form form)
    {
        var remaining = await _db.Questions.CountAsync(q => q.FormId == form.Id && q.DeletedAt == null);
        if (remaining > 0 || form.Status == null)
            return;

        var draftStatus = await _db.FormStatuses.FirstAsync(s => s.Status == "draft");
        if (form.StatusId != draftStatus.Id)
        {
            form.StatusId = draftStatus.Id;
            form.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }
    }

    private static QuestionResponse MapQuestion(Question q) => new()
    {
        Id = q.Id,
        FormId = q.FormId,
        TypeId = q.TypeId,
        Question = q.Question1,
        QuestionFormat = q.QuestionFormat ?? RichTextValidation.FormatOf(q.Question1),
        QuestionOrder = q.QuestionOrder,
        QuestionImage = q.QuestionImage,
        QuestionAudio = q.QuestionAudio,
        IsRequired = q.IsRequired,
        CorrectAnswer = q.CorrectAnswer,
        RandomizeOptions = q.RandomizeOptions,
        Points = q.Points,
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

    /// <summary>Satu kesalahan format pada baris impor tertentu.</summary>
    private sealed record ImportError(int RowNumber, string Field, string Message);

    private const long MaxPreviewImageBytes = 1_500_000;

    /// <summary>
    /// Ubah byte gambar hasil ekstraksi dokumen menjadi data URI base64 untuk
    /// response preview. Return null jika tidak ada / terlalu besar agar
    /// payload preview tetap ringan.
    /// </summary>
    private static string? ToImageDataUri(byte[]? bytes, string? ext)
    {
        if (bytes is not { Length: > 0 } || bytes.Length > MaxPreviewImageBytes)
            return null;

        var mime = ext?.ToLowerInvariant() switch
        {
            ".png" => "image/png",
            ".jpg" or ".jpeg" => "image/jpeg",
            ".gif" => "image/gif",
            ".webp" => "image/webp",
            _ => "application/octet-stream",
        };

        return $"data:{mime};base64,{Convert.ToBase64String(bytes)}";
    }

    private static string FormatImportError(ImportError e) =>
        $"Baris {e.RowNumber} ({e.Field}): {e.Message}";

    /// <summary>
    /// Validasi baris hasil parse. Return daftar error terstruktur per baris;
    /// baris yang error akan dilewati saat preview maupun impor.
    /// </summary>
    private static List<ImportError> ValidateImportRows(List<ImportRow> rows, List<int> validTypeIds)
    {
        var errors = new List<ImportError>();

        foreach (var row in rows)
        {
            if (string.IsNullOrWhiteSpace(row.Question))
            {
                errors.Add(new ImportError(row.RowNumber, "question", "Teks pertanyaan kosong"));
                continue;
            }

            if (!validTypeIds.Contains(row.TypeId))
            {
                errors.Add(new ImportError(row.RowNumber, "type_id",
                    $"type_id '{row.TypeId}' tidak dikenal (1=Essay, 2=Multiple Choice, 3=Checkbox, 4=Date Time, 5=True False)"));
                continue;
            }
        }

        return errors;
    }

    private static int ResolveTypeId(string? val, int optionsCount)
    {
        if (!string.IsNullOrWhiteSpace(val))
        {
            var clean = val.Trim().ToLowerInvariant().Replace("_", " ").Replace("-", " ");
            if (int.TryParse(clean, out var id) && id >= 1 && id <= 5)
                return id;
            if (clean.Contains("essay") || clean.Contains("esai") || clean.Contains("text") || clean.Contains("teks"))
                return 1;
            if (clean.Contains("pilihan ganda") || clean.Contains("multiple choice") || clean.Contains("pg") || clean.Contains("pilihan") || clean.Contains("option"))
                return 2;
            if (clean.Contains("checkbox") || clean.Contains("centang") || clean.Contains("kotak"))
                return 3;
            if (clean.Contains("date") || clean.Contains("waktu") || clean.Contains("tanggal"))
                return 4;
            if (clean.Contains("true") || clean.Contains("benar") || clean.Contains("salah") || clean.Contains("false"))
                return 5;
        }
        return optionsCount > 0 ? 2 : 1;
    }

    private static string NormalizeKey(string k) =>
        System.Text.RegularExpressions.Regex.Replace(k.ToLowerInvariant(), @"[^a-z0-9]", "");

    private static List<ImportRow> ParseExcel(Stream stream)
    {
        using var workbook = new XLWorkbook(stream);
        var sheet = workbook.Worksheet(1);
        var rows = new List<ImportRow>();

        var headerRow = sheet.Row(1);
        var colMap = new Dictionary<string, int>();
        foreach (var cell in headerRow.CellsUsed())
        {
            var raw = cell.GetString().Trim();
            if (string.IsNullOrEmpty(raw)) continue;
            var norm = NormalizeKey(raw);
            colMap[norm] = cell.Address.ColumnNumber;
        }

        int FindCol(params string[] aliases)
        {
            foreach (var a in aliases)
            {
                var norm = NormalizeKey(a);
                if (colMap.TryGetValue(norm, out var col)) return col;
            }
            return 0;
        }

        var qCol = FindCol("question", "pertanyaan", "soal", "teksoal", "q");
        var tCol = FindCol("type_id", "type", "tipe", "tipesoal", "jenissoal", "jenis");
        var oCol = FindCol("order", "no", "nomor", "urutan");
        var rCol = FindCol("is_required", "required", "wajib", "wajibdiisi");
        var randCol = FindCol("randomize_options", "acakpilihan", "acakopsi", "acak");
        var caCol = FindCol("correct_answer", "jawabanbenar", "kuncijawaban", "kunci", "answer");
        var optCol = FindCol("options", "pilihan", "opsi", "pilihanjawaban", "opsijawaban");

        var optACol = FindCol("option_a", "pilihan_a", "opsi_a", "a");
        var optBCol = FindCol("option_b", "pilihan_b", "opsi_b", "b");
        var optCCol = FindCol("option_c", "pilihan_c", "opsi_c", "c");
        var optDCol = FindCol("option_d", "pilihan_d", "opsi_d", "d");
        var optECol = FindCol("option_e", "pilihan_e", "opsi_e", "e");

        foreach (var row in sheet.RowsUsed().Skip(1))
        {
            var importRow = new ImportRow { RowNumber = row.RowNumber() };

            if (qCol > 0)
                importRow.Question = row.Cell(qCol).GetString().Trim();

            string? typeRaw = null;
            if (tCol > 0)
                typeRaw = row.Cell(tCol).GetString().Trim();

            if (oCol > 0)
            {
                var val = row.Cell(oCol).GetString().Trim();
                if (int.TryParse(val, out var order))
                    importRow.Order = order;
            }

            if (rCol > 0)
            {
                var val = row.Cell(rCol).GetString().Trim().ToLowerInvariant();
                importRow.IsRequired = val is "true" or "1" or "yes" or "ya";
            }

            if (randCol > 0)
            {
                var val = row.Cell(randCol).GetString().Trim().ToLowerInvariant();
                importRow.RandomizeOptions = val is "true" or "1" or "yes" or "ya";
            }

            if (caCol > 0)
                importRow.CorrectAnswer = row.Cell(caCol).GetString().Trim();

            if (optCol > 0)
            {
                var raw = row.Cell(optCol).GetString().Trim();
                if (!string.IsNullOrEmpty(raw))
                {
                    importRow.Options = raw.Split(new[] { '|', '\n', ';' }, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).ToList();
                }
            }

            // Also check individual option columns if options column is empty
            if (importRow.Options.Count == 0)
            {
                var extraOpts = new List<string>();
                foreach (var colIdx in new[] { optACol, optBCol, optCCol, optDCol, optECol })
                {
                    if (colIdx > 0)
                    {
                        var optText = row.Cell(colIdx).GetString().Trim();
                        if (!string.IsNullOrEmpty(optText)) extraOpts.Add(optText);
                    }
                }
                if (extraOpts.Count > 0) importRow.Options = extraOpts;
            }

            importRow.TypeId = ResolveTypeId(typeRaw, importRow.Options.Count);

            if (!string.IsNullOrWhiteSpace(importRow.Question) || importRow.Options.Count > 0)
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

        var rawHeaders = ParseCsvLine(headerLine);
        var colMap = new Dictionary<string, int>();
        for (var i = 0; i < rawHeaders.Count; i++)
        {
            var norm = NormalizeKey(rawHeaders[i]);
            if (!string.IsNullOrEmpty(norm)) colMap[norm] = i;
        }

        int FindIdx(params string[] aliases)
        {
            foreach (var a in aliases)
            {
                var norm = NormalizeKey(a);
                if (colMap.TryGetValue(norm, out var idx)) return idx;
            }
            return -1;
        }

        var qIdx = FindIdx("question", "pertanyaan", "soal", "teksoal", "q");
        var tIdx = FindIdx("type_id", "type", "tipe", "tipesoal", "jenissoal", "jenis");
        var oIdx = FindIdx("order", "no", "nomor", "urutan");
        var rIdx = FindIdx("is_required", "required", "wajib", "wajibdiisi");
        var randIdx = FindIdx("randomize_options", "acakpilihan", "acakopsi", "acak");
        var caIdx = FindIdx("correct_answer", "jawabanbenar", "kuncijawaban", "kunci", "answer");
        var optIdx = FindIdx("options", "pilihan", "opsi", "pilihanjawaban", "opsijawaban");

        var optAIdx = FindIdx("option_a", "pilihan_a", "opsi_a", "a");
        var optBIdx = FindIdx("option_b", "pilihan_b", "opsi_b", "b");
        var optCIdx = FindIdx("option_c", "pilihan_c", "opsi_c", "c");
        var optDIdx = FindIdx("option_d", "pilihan_d", "opsi_d", "d");
        var optEIdx = FindIdx("option_e", "pilihan_e", "opsi_e", "e");

        var lineNum = 1;
        while (!reader.EndOfStream)
        {
            lineNum++;
            var line = reader.ReadLine();
            if (string.IsNullOrWhiteSpace(line)) continue;

            var values = ParseCsvLine(line);
            var importRow = new ImportRow { RowNumber = lineNum };

            if (qIdx >= 0 && qIdx < values.Count)
                importRow.Question = values[qIdx].Trim();

            string? typeRaw = null;
            if (tIdx >= 0 && tIdx < values.Count)
                typeRaw = values[tIdx].Trim();

            if (oIdx >= 0 && oIdx < values.Count)
            {
                if (int.TryParse(values[oIdx].Trim(), out var order))
                    importRow.Order = order;
            }

            if (rIdx >= 0 && rIdx < values.Count)
            {
                var val = values[rIdx].Trim().ToLowerInvariant();
                importRow.IsRequired = val is "true" or "1" or "yes" or "ya";
            }

            if (randIdx >= 0 && randIdx < values.Count)
            {
                var val = values[randIdx].Trim().ToLowerInvariant();
                importRow.RandomizeOptions = val is "true" or "1" or "yes" or "ya";
            }

            if (caIdx >= 0 && caIdx < values.Count)
                importRow.CorrectAnswer = values[caIdx].Trim();

            if (optIdx >= 0 && optIdx < values.Count)
            {
                var raw = values[optIdx].Trim();
                if (!string.IsNullOrEmpty(raw))
                {
                    importRow.Options = raw.Split(new[] { '|', '\n', ';' }, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).ToList();
                }
            }

            if (importRow.Options.Count == 0)
            {
                var extraOpts = new List<string>();
                foreach (var idx in new[] { optAIdx, optBIdx, optCIdx, optDIdx, optEIdx })
                {
                    if (idx >= 0 && idx < values.Count)
                    {
                        var optText = values[idx].Trim();
                        if (!string.IsNullOrEmpty(optText)) extraOpts.Add(optText);
                    }
                }
                if (extraOpts.Count > 0) importRow.Options = extraOpts;
            }

            importRow.TypeId = ResolveTypeId(typeRaw, importRow.Options.Count);

            if (!string.IsNullOrWhiteSpace(importRow.Question) || importRow.Options.Count > 0)
                rows.Add(importRow);
        }

        return rows;
    }

/// Satu potongan konten dokumen: baris teks atau gambar (urut sesuai dokumen).
/// IsSubItem = baris dari daftar bernomor yang "restart" (sub-enumerasi di
/// dalam stem soal, contoh "1. Perkembangan humanisme... 2. Adanya ...")
/// — harus menempel ke teks soal, bukan dianggap soal/opsi baru.
private sealed record ImportDocEntry(string? Text, byte[]? ImageBytes, string? ImageExt, bool IsSubItem = false);

private static readonly System.Text.RegularExpressions.Regex ImportQuestionStartRegex = new(@"^(\d{1,3})[\.\):]\s*(.*)$");

// Opsi: "A. ..." / "b) ..." / "(c) ..." / "D  ..." (huruf + titik/kurung/spasi ganda)
private static readonly System.Text.RegularExpressions.Regex ImportOptionRegex = new(@"^\(?([a-eA-E])(?:[\.\):]\s*|\s{2,})(.*)$");

// Pemisah opsi yang MENEMPEL di tengah paragraf, contoh:
// "...utama…A. Mengurangi tenaga kerjaB  Menarik investasi C  Menguasai..."
// "...tersebut?A. Produksi meningkat..."
// Marker: huruf kapital a-e yang menempel pada karakter kata/angka/elipsis/
// tanda tutup kalimat, diikuti titik ATAU spasi minimal 2 — dengan syarat
// >=2 marker agar teks biasa (mis. "yaitu A, B, C") tidak ikut terpecah.
private static readonly System.Text.RegularExpressions.Regex ImportInlineOptionSplit = new(@"(?<=[a-z0-9….\)\?!])([A-E])(?:\.|\s{2,})");
private static readonly System.Text.RegularExpressions.Regex ImportJunkDigitsRegex = new(@"^\d{9,}$");

/// State penomoran docx selama satu file diekstrak.
private sealed class DocxNumberingState
{
    public Dictionary<(int NumId, int Ilvl), int> Counters = new();
    /// <summary>Daftar desimal yang terdeteksi RESTART → semua itemnya sub-enumerasi.</summary>
    public HashSet<(int NumId, int Ilvl)> SubListKeys = new();
    /// <summary>Nomor soal (desimal) terakhir yang dianggap level utama.</summary>
    public int LastMainDecimal;
}

private static List<ImportDocEntry> ParseDocxEntries(Stream stream)
{
    var entries = new List<ImportDocEntry>();
    using var doc = WordprocessingDocument.Open(stream, false);
    var main = doc.MainDocumentPart;
    // main.Document adalah elemen <w:document>; paragraf ada di dalam <w:body>.
    var body = main?.Document?.Body;
    if (main == null || body == null) return entries;

    // Word auto-numbering: nomor/huruf daftar TIDAK ada di InnerText karena
    // dirender dari numbering.xml. Sintesis ulang labelnya agar parser bisa
    // membedakan soal bernomor ("34."), opsi berhuruf ("a."), dan sub-item.
    var numbering = main.NumberingDefinitionsPart?.Numbering;
    var state = new DocxNumberingState();

    foreach (var para in body.Descendants<Paragraph>())
    {
        var (prefix, isSubItem) = ResolveNumberingPrefix(para, numbering, state);

        // Teks paragraf lebih dulu (baris bernomor menandai awal soal),
        // lalu gambar yang tertanam — persamaan/figure sering berupa gambar.
        var text = $"{prefix}{para.InnerText}".Trim();
        if (text.Length > 0)
            entries.Add(new ImportDocEntry(text, null, null, isSubItem));

        foreach (var blip in para.Descendants<DocumentFormat.OpenXml.Drawing.Blip>())
        {
            var relId = blip.Embed?.Value;
            if (string.IsNullOrEmpty(relId)) continue;
            try
            {
                var part = main.GetPartById(relId!);
                using var partStream = part.GetStream();
                using var ms = new MemoryStream();
                partStream.CopyTo(ms);
                var bytes = ms.ToArray();
                if (bytes.Length == 0) continue;

                var ext = FileValidation.DetectImageExt(new MemoryStream(bytes))
                    ?? ExtFromContentType(part.ContentType);
                if (ext == null || bytes.Length > FileValidation.MaxImageBytes) continue;

                entries.Add(new ImportDocEntry(null, bytes, ext));
            }
            catch
            {
                // ponytail: gambar rusak / relasi hilang → lewati
            }
        }
    }

    return entries;
}

/// <summary>
/// Sintesis label penomoran Word untuk satu paragraf.
/// - Format desimal yang berlanjut → prefix "N." (soal baru).
/// - Desimal yang RESTART / daftar baru setelah soal-soal → sub-enumerasi
///   di dalam stem soal (tanpa prefix + flag IsSubItem).
/// - Huruf/romawi → prefix "a." / "i." (opsi jawaban).
/// - Bullet / tanpa nomor → tidak ada prefix.
/// </summary>
private static (string Prefix, bool IsSubItem) ResolveNumberingPrefix(
    Paragraph para, DocumentFormat.OpenXml.Wordprocessing.Numbering? numbering,
    DocxNumberingState state)
{
    // Reset sub-list tracking at the start of each new question so that
    // sub-items from a previous question don't bleed into the next one.
    state.SubListKeys.Clear();

    var counters = state.Counters;
    var numPr = para.ParagraphProperties?.GetFirstChild<DocumentFormat.OpenXml.Wordprocessing.NumberingProperties>();
    var numIdVal = numPr?.GetFirstChild<DocumentFormat.OpenXml.Wordprocessing.NumberingId>()?.Val;
    if (numIdVal == null || numbering == null) return ("", false);

    var numId = numIdVal.Value;
    var ilvl = numPr!.GetFirstChild<DocumentFormat.OpenXml.Wordprocessing.NumberingLevelReference>()?.Val?.Value ?? 0;

    var num = numbering.Elements<DocumentFormat.OpenXml.Wordprocessing.NumberingInstance>()
        .FirstOrDefault(n => n.NumberID?.Value == numId);
    var abstractNumId = num?.AbstractNumId?.Val;
    if (abstractNumId == null) return ("", false);

    var abs = numbering.Elements<DocumentFormat.OpenXml.Wordprocessing.AbstractNum>()
        .FirstOrDefault(a => a.AbstractNumberId?.Value == abstractNumId);
    var lvl = abs?.Elements<DocumentFormat.OpenXml.Wordprocessing.Level>()
        .FirstOrDefault(l => l.LevelIndex?.Value == ilvl);
    // Nama format: "decimal", "lowerLetter", "upperLetter", "bullet", dll.
    var fmtStr = lvl?.NumberingFormat?.Val?.ToString()?.ToLowerInvariant() ?? "";
    if (fmtStr is "" or "bullet" or "none") return ("", false);

    // Nilai awal: startOverride pada instance > start pada level > 1
    var start = lvl?.StartNumberingValue?.Val?.Value ?? 1;
    var ov = num?.Elements<DocumentFormat.OpenXml.Wordprocessing.LevelOverride>()
        .FirstOrDefault(o => o.LevelIndex?.Value == ilvl);
    if (ov?.StartOverrideNumberingValue?.Val != null)
        start = ov.StartOverrideNumberingValue.Val.Value;

    var key = (numId, ilvl);
    var hadPrevious = counters.ContainsKey(key);
    // Level di atas naik → reset counter level lebih dalam pada numId yang sama
    foreach (var deeper in counters.Keys.Where(k => k.NumId == numId && k.Ilvl > ilvl).ToList())
        counters.Remove(deeper);

    var next = hadPrevious ? counters[key] + 1 : start;
    counters[key] = next;

    string label;

    if (fmtStr != "decimal")
    {
        // Huruf / romawi → opsi jawaban
        label = fmtStr switch
        {
            "lowerletter" => ToLetterSequence(next, false),
            "upperletter" => ToLetterSequence(next, true),
            "lowerroman" => ToRoman(next).ToLowerInvariant(),
            "upperroman" => ToRoman(next),
            _ => next.ToString(),
        };
        return ($"{label}. ", false);
    }

    // Desimal: soal baru ATAU enumerasi di dalam stem soal.
    // Soal utama selalu MONOTONIK naik (35 → 37, meski ada celah karena soal
    // di antaranya memakai nomor literal). Enumerasi stem selalu restart ke
    // angka kecil (1, 2, ...) — itu yang ditandai sebagai sub-item.
    var knownSubList = state.SubListKeys.Contains(key);

    var monotonic = next > state.LastMainDecimal;

    if (knownSubList || (!monotonic && state.LastMainDecimal > 0))
    {
        state.SubListKeys.Add(key);
        return ("", true);
    }

    state.LastMainDecimal = next;
    // Jangan hapus SubListKeys di sini — akan di-clear di awal fungsi selanjutnya.
    return ($"{next}. ", false);
}

private static string ToLetterSequence(int n, bool upper)
{
    var letters = "";
    while (n > 0)
    {
        n--;
        letters = (char)((upper ? 'A' : 'a') + n % 26) + letters;
        n /= 26;
    }
    return letters;
}

private static string ToRoman(int n)
{
    var map = new[] { (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"),
        (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"),
        (5, "V"), (4, "IV"), (1, "I") };
    var result = "";
    foreach (var (v, sym) in map)
    {
        while (n >= v) { result += sym; n -= v; }
    }
    return result;
}

private static string? ExtFromContentType(string contentType) =>
    contentType.ToLowerInvariant() switch
    {
        "image/png" or "image/x-png" => ".png",
        "image/jpeg" or "image/jpg" or "image/pjpeg" => ".jpg",
        "image/gif" => ".gif",
        "image/webp" => ".webp",
        _ => null,
    };

private static List<ImportDocEntry> ParsePdfEntries(Stream stream)
{
    var entries = new List<ImportDocEntry>();
    using var pdf = PdfDocument.Open(stream);

    foreach (var page in pdf.GetPages())
    {
        // (Y, urutan, entry) — Y tinggi = bagian atas halaman
        var items = new List<(double Y, int Kind, ImportDocEntry Entry)>();

        try
        {
            foreach (var lineGroup in page.GetWords()
                         .GroupBy(w => Math.Round(w.BoundingBox.BottomLeft.Y / 3)))
            {
                var text = string.Join(" ", lineGroup
                    .OrderBy(w => w.BoundingBox.Left)
                    .Select(w => w.Text)).Trim();
                if (text.Length == 0) continue;
                items.Add((lineGroup.Key, 0, new ImportDocEntry(text, null, null)));
            }
        }
        catch
        {
            // fallback ekstraksi teks sederhana
            foreach (var line in page.Text.Split('\n', StringSplitOptions.RemoveEmptyEntries))
            {
                var t = line.Trim();
                if (t.Length > 0)
                    items.Add((0d, 0, new ImportDocEntry(t, null, null)));
            }
        }

        try
        {
            foreach (var image in page.GetImages())
            {
                byte[]? bytes;
                string? ext;
                if (image.TryGetPng(out var png))
                {
                    bytes = png;
                    ext = ".png";
                }
                else
                {
                    bytes = image.RawBytes.ToArray();
                    ext = FileValidation.DetectImageExt(new MemoryStream(bytes));
                }

                if (bytes == null || bytes.Length == 0 || ext == null) continue;
                if (bytes.Length > FileValidation.MaxImageBytes) continue;

                var y = image.Bounds.Top;
                items.Add((y, 1, new ImportDocEntry(null, bytes, ext)));
            }
        }
        catch
        {
            // ponytail: gambar tidak dapat didekode → lewati
        }

        entries.AddRange(items
            .OrderByDescending(x => x.Y)
            .ThenBy(x => x.Kind)
            .Select(x => x.Entry));
    }

    return entries;
}

    /// <summary>
    /// Ubah urutan entry dokumen (teks + gambar) menjadi baris soal.
    /// Heuristik:
    /// - Baris bernomor "1." / "1)" memulai soal baru; "A." / "(a)" / "A  " opsi.
    /// - Opsi yang menempel di tengah paragraf ("...adalah…A. xB  y") dipecah dulu.
    /// - Baris sebelum soal bernomor pertama dianggap judul/header dan dibuang
    ///   begitu soal bernomor muncul (dokumen tanpa penomoran tetap aman).
    /// - Artefak ekstraksi PDF (baris 1 karakter, deretan angka panjang) dilewati.
    /// - Gambar menempel ke soal yang sedang berjalan (atau soal berikutnya).
    /// - Format berlabel template lama (question:/type_id:/dst) tetap didukung.
    /// </summary>
    private static List<ImportRow> ParseStructuredEntries(List<ImportDocEntry> entries)
    {
        // Pra-pembersihan: buang artefak & pecah opsi menempel, sehingga loop
        // utama bisa melakukan lookahead ke baris berikutnya.
        var items = new List<ImportDocEntry>();
        foreach (var entry in entries)
        {
            if (entry.ImageBytes != null)
            {
                items.Add(entry);
                continue;
            }

            var rawEntry = entry.Text?.Trim() ?? "";
            if (rawEntry.Length <= 1 || ImportJunkDigitsRegex.IsMatch(rawEntry)) continue;

            foreach (var segment in SplitInlineOptions(rawEntry))
            {
                var l = segment.Trim();
                if (l.Length <= 1 || ImportJunkDigitsRegex.IsMatch(l)) continue;
                items.Add(new ImportDocEntry(l, null, null));
            }
        }

        var rows = new List<ImportRow>();
        ImportRow? current = null;
        ImportRow? preambleRow = null;
        var sawNumberedQuestion = false;
        var inUnletteredRun = false;
        var rowNum = 0;
        byte[]? pendingImage = null;
        string? pendingImageExt = null;

        void AttachPending(ImportRow row)
        {
            if (pendingImage == null || row.ImageBytes != null) return;
            row.ImageBytes = pendingImage;
            row.ImageExt = pendingImageExt;
            pendingImage = null;
            pendingImageExt = null;
        }

        void NewRow(string question, int typeId = 2)
        {
            if (current != null && !string.IsNullOrWhiteSpace(current.Question))
                rows.Add(current);

            current = new ImportRow { RowNumber = ++rowNum };
            current.Question = question.Trim();
            current.TypeId = typeId;
            AttachPending(current);
            inUnletteredRun = false;
        }

        // Baris pendek tanpa tanda tutup kalimat setelah pertanyaan berakhir —
        // kandidat opsi TANPA huruf (contoh: daftar "Bergabung sepenuhnya ...").
        bool IsUnletteredOptionCandidate(int idx)
        {
            if (idx < 0 || idx >= items.Count) return false;
            var e = items[idx];
            if (e.ImageBytes != null) return false;
            var t = e.Text?.Trim() ?? "";
            if (t.Length < 2 || t.Length > 80) return false;
            if (t[^1] is '…' or '?' or ':' or ';') return false;
            if (ImportQuestionStartRegex.IsMatch(t)) return false;
            var lower = t.ToLowerInvariant();
            if (lower.StartsWith("question:") || lower.StartsWith("type_id:") ||
                lower.StartsWith("options:") || lower.StartsWith("correct_answer:") ||
                lower.StartsWith("is_required:") || lower.StartsWith("randomize_options:"))
                return false;
            return true;
        }

        for (var i = 0; i < items.Count; i++)
        {
            var entry = items[i];

            // Gambar: milik pertanyaan yang sedang berjalan, atau tunggu soal berikutnya
            if (entry.ImageBytes != null)
            {
                if (current == null)
                {
                    pendingImage ??= entry.ImageBytes;
                    pendingImageExt ??= entry.ImageExt;
                }
                else if (current.ImageBytes == null)
                {
                    current.ImageBytes = entry.ImageBytes;
                    current.ImageExt = entry.ImageExt;
                }
                continue;
            }

            var line = entry.Text?.Trim() ?? "";

            // Sub-enumerasi di dalam stem soal ("1. Perkembangan humanisme...")
            // — menempel ke teks soal yang sedang berjalan.
            if (entry.IsSubItem)
            {
                rowNum++;
                if (current != null)
                {
                    current.Question = $"{current.Question} {line}".Trim();
                }
                else
                {
                    preambleRow ??= new ImportRow { RowNumber = ++rowNum };
                    preambleRow.Question = $"{preambleRow.Question} {line}".Trim();
                    current = preambleRow;
                }
                continue;
            }

            rowNum++;
            var lower = line.ToLowerInvariant();

            // Format berlabel (kompatibel template lama)
            if (lower.StartsWith("question:"))
            {
                sawNumberedQuestion = true;
                preambleRow = null;
                NewRow(line[9..].Trim(), 2);
                continue;
            }
            if (current != null && lower.StartsWith("type_id:") &&
                int.TryParse(line[8..].Trim(), out var typeId))
            {
                current.TypeId = typeId;
                continue;
            }
            if (current != null && lower.StartsWith("is_required:"))
            {
                current.IsRequired = line[12..].Trim() is "true" or "yes" or "1";
                continue;
            }
            if (current != null && lower.StartsWith("randomize_options:"))
            {
                current.RandomizeOptions = line[18..].Trim() is "true" or "yes" or "1";
                continue;
            }
            if (current != null && lower.StartsWith("correct_answer:"))
            {
                current.CorrectAnswer = line[15..].Trim();
                continue;
            }
            if (current != null && lower.StartsWith("options:"))
            {
                current.Options = line[8..].Trim()
                    .Split('|', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
                    .ToList();
                continue;
            }

            // Soal bernomor: "1. ..." / "1) ..." — teks setelah nomor boleh kosong
            // (lanjutan teksnya menyusul di baris berikutnya)
            var qm = ImportQuestionStartRegex.Match(line);
            if (qm.Success)
            {
                // Pembuka (judul/header dokumen) dibuang begitu soal bernomor
                // pertama muncul — dokumen tanpa penomoran tidak terdampak.
                if (current == preambleRow && !sawNumberedQuestion)
                {
                    current = null;
                    preambleRow = null;
                }
                sawNumberedQuestion = true;
                NewRow(qm.Groups[2].Value, 2);
                continue;
            }

            // Opsi berhuruf: "A. ..." / "b) ..." / "(c) ..." / "D  ..."
            var om = ImportOptionRegex.Match(line);
            if (om.Success && current != null)
            {
                current.Options.Add(
                    $"{om.Groups[1].Value.ToUpperInvariant()}. {om.Groups[2].Value.Trim()}");
                continue;
            }

            // Lanjutan teks pertanyaan sebelumnya
            if (current != null)
            {
                var endsSentence = line.EndsWith('.') || line.EndsWith('…') ||
                                   line.EndsWith('?') || line.EndsWith(':') ||
                                   line.EndsWith('!');
                var stem = current.Question ?? "";
                var questionEnded = stem.Length > 0 &&
                                    stem[^1] is '.' or '…' or '?' or ':' or '!';

                // Opsi tanpa huruf: mulai run jika pertanyaan sudah selesai dan
                // minimal 2 baris pendek berturut-turut mengikuti.
                if (current.Options.Count == 0 && !inUnletteredRun &&
                    questionEnded && IsUnletteredOptionCandidate(i) &&
                    IsUnletteredOptionCandidate(i + 1))
                {
                    inUnletteredRun = true;
                    current.Options.Add(line);
                    continue;
                }
                if (inUnletteredRun && IsUnletteredOptionCandidate(i))
                {
                    current.Options.Add(line);
                    continue;
                }
                inUnletteredRun = false;

                // Paragraf panjang yang diakhiri tanda tutup kalimat saat soal
                // aktif sudah punya opsi → kemungkinan soal berikutnya pada
                // dokumen tanpa penomoran.
                if (current.Options.Count > 0 && endsSentence && line.Length >= 30)
                {
                    NewRow(line, 2);
                }
                else
                {
                    current.Question = $"{current.Question} {line}".Trim();
                }
            }
            else
            {
                // Konten sebelum soal bernomor pertama: simpan sebagai pembuka,
                // bisa jadi judul (dibuang nanti) atau soal pertama (dokumen
                // tanpa penomoran).
                preambleRow ??= new ImportRow { RowNumber = ++rowNum };
                preambleRow.Question = $"{preambleRow.Question} {line}".Trim();
                current = preambleRow;
            }
        }

        if (current != null && !string.IsNullOrWhiteSpace(current.Question))
            rows.Add(current);

        return rows;
    }

    /// <summary>
    /// Pecah satu baris/paragraf yang mengandung opsi menempel menjadi beberapa
    /// segmen. Contoh: "...utama…A. Mengurangi kerjaB  Menarik investasi" menjadi
    /// ["...utama…", "A. Mengurangi kerja", "B  Menarik investasi"].
    /// Marker sudah mensyaratkan huruf kapital menempel langsung pada karakter
    /// kata/angka sebelumnya sehingga aman dipakai bahkan untuk 1 marker saja.
    /// </summary>
    private static List<string> SplitInlineOptions(string text)
    {
        var matches = ImportInlineOptionSplit.Matches(text);
        if (matches.Count < 1)
            return new List<string> { text };

        var parts = new List<string>();
        var idx = 0;
        foreach (System.Text.RegularExpressions.Match m in matches)
        {
            if (m.Index > idx) parts.Add(text[idx..m.Index]);
            idx = m.Index;
        }
        parts.Add(text[idx..]);
        return parts;
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

    /// <summary>Gambar yang diekstrak dari dokumen (docx/pdf), jika ada.</summary>
    public byte[]? ImageBytes { get; set; }
    public string? ImageExt { get; set; }
}