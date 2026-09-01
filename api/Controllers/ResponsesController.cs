using System.Security.Claims;
using FormUpAPI.Models;
using FormUpAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace FormUpAPI.Controllers;

[ApiController]
[Authorize]
public class ResponsesController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public ResponsesController(FormUpDbContext db)
    {
        _db = db;
    }

    [HttpPost("api/forms/{formId}/responses")]
    [AllowAnonymous]
    [EnableRateLimiting("submit")]
    public async Task<ActionResult<ApiResponse<object>>> Submit(int formId, [FromBody] SubmitResponseRequest request)
    {
        return await ResponseSubmission.SaveAsync(_db, User, formId, request);
    }

    [HttpGet("api/forms/{formId}/responses")]
    public async Task<ActionResult<ApiResponse<object>>> GetAll(int formId, [FromQuery] int? page, [FromQuery] int? pageSize)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var query = _db.Responses
            .Include(r => r.Status)
            .Include(r => r.Respondent)
            .Where(r => r.FormId == formId)
            .OrderByDescending(r => r.SubmittedAt)
            .Select(r => new ResponseListItem
            {
                Id = r.Id,
                RespondentName = r.Respondent != null ? r.Respondent.Fullname : r.RespondentName,
                Status = r.Status!.Status,
                SubmittedAt = r.SubmittedAt ?? r.CreatedAt ?? DateTime.UtcNow,
            });

        if (page.HasValue && pageSize.HasValue && pageSize > 0)
        {
            var total = await query.CountAsync();
            var items = await query
                .Skip((page.Value - 1) * pageSize.Value)
                .Take(pageSize.Value)
                .ToListAsync();

            return Ok(new ApiResponse<object>(200, "OK", new
            {
                items,
                total,
                page = page.Value,
                pageSize = pageSize.Value,
            }));
        }

        var all = await query.ToListAsync();
        return Ok(new ApiResponse<object>(200, "OK", all));
    }

    [HttpGet("api/forms/{formId}/responses/{id}")]
    public async Task<ActionResult<ApiResponse<object>>> GetById(int formId, int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var response = await _db.Responses
            .Include(r => r.Status)
            .Include(r => r.Respondent)
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Question)
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Option)
            .FirstOrDefaultAsync(r => r.Id == id && r.FormId == formId);

        if (response == null)
            return NotFound(new ApiResponse<object>(404, "Response not found"));

        var detail = new ResponseDetail
        {
            Id = response.Id,
            FormId = response.FormId,
            RespondentName = response.Respondent?.Fullname ?? response.RespondentName,
            Status = response.Status?.Status ?? "unknown",
            SubmittedAt = response.SubmittedAt ?? response.CreatedAt ?? DateTime.UtcNow,
            Answers = response.RespondentAnswers.Select(a => new AnswerDetail
            {
                QuestionId = a.QuestionId,
                Question = a.Question?.Question1 ?? "",
                QuestionFormat = a.Question == null
                    ? null
                    : a.Question.QuestionFormat ?? RichTextValidation.FormatOf(a.Question.Question1),
                TypeId = a.Question?.TypeId ?? 0,
                OptionId = a.OptionId,
                OptionText = a.Option?.OptionText,
                AnswerValue = a.AnswerValue,
            }).ToList(),
        };

        return Ok(new ApiResponse<object>(200, "OK", detail));
    }

    /// <summary>
    /// Hasil lengkap satu respon (skor, kunci jawaban, opsi) untuk pemilik form.
    /// Dipakai screen Respondent Detail.
    /// </summary>
    [HttpGet("api/forms/{formId}/responses/{id}/result")]
    public async Task<ActionResult<ApiResponse<object>>> GetResult(int formId, int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var response = await _db.Responses
            .Include(r => r.Respondent)
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Option)
            .FirstOrDefaultAsync(r => r.Id == id && r.FormId == formId);

        if (response == null)
            return NotFound(new ApiResponse<object>(404, "Response not found"));

        var questions = await _db.Questions
            .Include(q => q.OptionQuestions)
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .ToListAsync();

        return Ok(new ApiResponse<object>(200, "OK", ResponseScorer.BuildResult(form, response, questions)));
    }

    /// <summary>
    /// Semua attempt responden yang sama pada form yang sama (dicocokkan lewat
    /// akun login; fallback ke nama yang diketik saat submit sebagai guest).
    /// </summary>
    [HttpGet("api/forms/{formId}/responses/{id}/attempts")]
    public async Task<ActionResult<ApiResponse<object>>> GetRespondentAttempts(int formId, int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var target = await _db.Responses
            .FirstOrDefaultAsync(r => r.Id == id && r.FormId == formId);

        if (target == null)
            return NotFound(new ApiResponse<object>(404, "Response not found"));

        var sameRespondent = _db.Responses.Where(r => r.FormId == formId);
        sameRespondent = target.RespondentId.HasValue
            ? sameRespondent.Where(r => r.RespondentId == target.RespondentId)
            : sameRespondent.Where(
                r => r.RespondentId == null && r.RespondentName != null && r.RespondentName == target.RespondentName);

        var showScore = form.FormSetting?.ShowScore == true;
        var attempts = await sameRespondent
            .OrderByDescending(r => r.SubmittedAt)
            .Select(r => new MyAttemptDto
            {
                ResponseId = r.Id,
                SubmittedAt = r.SubmittedAt,
                ShowScore = showScore,
            })
            .ToListAsync();

        // Skor per attempt (butuh koreksi jawaban).
        if (showScore)
        {
            var questions = await _db.Questions
                .Include(q => q.OptionQuestions)
                .Where(q => q.FormId == formId && q.DeletedAt == null)
                .ToListAsync();

            var ids = attempts.Select(a => a.ResponseId).ToList();
            var rows = await _db.Responses
                .Where(r => ids.Contains(r.Id))
                .Include(r => r.RespondentAnswers)
                    .ThenInclude(a => a.Option)
                .ToListAsync();

            foreach (var attempt in attempts)
            {
                var match = rows.FirstOrDefault(r => r.Id == attempt.ResponseId);
                if (match == null) continue;
                var built = ResponseScorer.BuildResult(form, match, questions);
                attempt.Score = built.Score;
                attempt.CorrectCount = built.CorrectCount;
                attempt.WrongCount = built.WrongCount;
            }
        }

        return Ok(new ApiResponse<object>(200, "OK", attempts));
    }

    [HttpPut("api/responses/{id}/status")]
    public async Task<ActionResult<ApiResponse<object>>> UpdateStatus(int id, [FromBody] UpdateResponseStatusRequest request)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var response = await _db.Responses
            .Include(r => r.Form)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (response == null)
            return NotFound(new ApiResponse<object>(404, "Response not found"));

        if (response.Form == null || response.Form.UserId != user.Id)
            return Forbid();

        var statusExists = await _db.ResponseStatuses.AnyAsync(s => s.Id == request.StatusId);
        if (!statusExists)
            return BadRequest(new ApiResponse<object>(400, "Invalid status ID"));

        response.StatusId = request.StatusId;
        response.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Status updated"));
    }

    [HttpGet("api/forms/{formId}/responses/export")]
    public async Task<IActionResult> Export(int formId, [FromQuery] string format = "csv", CancellationToken ct = default)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null, ct);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var questions = await _db.Questions
            .Where(q => q.FormId == formId && q.DeletedAt == null)
            .OrderBy(q => q.QuestionOrder)
            .ToListAsync(ct);

        var responses = await _db.Responses
            .Include(r => r.Respondent)
            .Include(r => r.Status)
            .Include(r => r.RespondentAnswers)
                .ThenInclude(a => a.Option)
            .Where(r => r.FormId == formId)
            .OrderByDescending(r => r.SubmittedAt)
            .ToListAsync(ct);

        var fmt = (format ?? "csv").ToLowerInvariant();
        return fmt switch
        {
            "xlsx" => ExportXlsx(formId, questions, responses),
            "pdf" => ExportPdf(formId, form, questions, responses),
            "csv" => ExportCsv(formId, questions, responses),
            _ => BadRequest(new ApiResponse<object>(400, "Supported formats: csv, xlsx, pdf")),
        };
    }

    private IActionResult ExportCsv(int formId, List<Question> questions, List<Response> responses)
    {
        using var writer = new System.IO.StringWriter();

        writer.Write("Response ID,Submitted At,Respondent");
        foreach (var q in questions)
            writer.Write($",{EscapeCsv(q.Question1)}");
        writer.WriteLine(",Status");

        foreach (var r in responses)
        {
            writer.Write($"{r.Id},{r.SubmittedAt:yyyy-MM-dd HH:mm:ss},{EscapeCsv(r.Respondent?.Fullname ?? r.RespondentName ?? "Anonymous")}");

            foreach (var q in questions)
            {
                var answer = r.RespondentAnswers.FirstOrDefault(a => a.QuestionId == q.Id);
                if (answer == null)
                {
                    writer.Write(",");
                }
                else if (answer.OptionId.HasValue)
                {
                    writer.Write($",{EscapeCsv(answer.Option?.OptionText ?? "")}");
                }
                else
                {
                    writer.Write($",{EscapeCsv(answer.AnswerValue ?? "")}");
                }
            }

            writer.WriteLine($",{r.Status?.Status ?? "unknown"}");
        }

        var csvText = writer.ToString();
        var preamble = System.Text.Encoding.UTF8.GetPreamble();
        var textBytes = System.Text.Encoding.UTF8.GetBytes(csvText);
        var csvBytes = new byte[preamble.Length + textBytes.Length];
        Buffer.BlockCopy(preamble, 0, csvBytes, 0, preamble.Length);
        Buffer.BlockCopy(textBytes, 0, csvBytes, preamble.Length, textBytes.Length);

        return File(csvBytes, "text/csv; charset=utf-8", $"responses-form-{formId}.csv");
    }

    private IActionResult ExportXlsx(int formId, List<Question> questions, List<Response> responses)
    {
        using var workbook = new ClosedXML.Excel.XLWorkbook();
        var sheet = workbook.Worksheets.Add("Responses");

        var headers = new List<string> { "Response ID", "Submitted At", "Respondent" };
        headers.AddRange(questions.Select(q => StripHtml(q.Question1)));
        headers.Add("Status");

        for (var c = 0; c < headers.Count; c++)
        {
            var cell = sheet.Cell(1, c + 1);
            cell.Value = headers[c];
            cell.Style.Font.Bold = true;
            cell.Style.Fill.BackgroundColor = ClosedXML.Excel.XLColor.FromHtml("#2A9D8F");
            cell.Style.Font.FontColor = ClosedXML.Excel.XLColor.White;
            cell.Style.Alignment.Horizontal = ClosedXML.Excel.XLAlignmentHorizontalValues.Center;
        }

        var row = 2;
        foreach (var r in responses)
        {
            var col = 1;
            sheet.Cell(row, col++).Value = r.Id;
            sheet.Cell(row, col++).Value = r.SubmittedAt?.ToString("yyyy-MM-dd HH:mm:ss") ?? "";
            sheet.Cell(row, col++).Value = r.Respondent?.Fullname ?? r.RespondentName ?? "Anonymous";
            foreach (var q in questions)
            {
                var answer = r.RespondentAnswers.FirstOrDefault(a => a.QuestionId == q.Id);
                string val = "";
                if (answer != null)
                    val = answer.OptionId.HasValue ? (answer.Option?.OptionText ?? "") : (answer.AnswerValue ?? "");
                sheet.Cell(row, col++).Value = StripHtml(val);
            }
            sheet.Cell(row, col).Value = r.Status?.Status ?? "unknown";
            row++;
        }

        sheet.Columns().AdjustToContents();
        sheet.SheetView.FreezeRows(1);

        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        stream.Position = 0;
        return File(stream.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"responses-form-{formId}.xlsx");
    }

    private IActionResult ExportPdf(int formId, Form form, List<Question> questions, List<Response> responses)
    {
        QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

        var headers = new List<string> { "ID", "Submitted", "Respondent" };
        headers.AddRange(questions.Select(q => StripHtml(q.Question1)));
        headers.Add("Status");

        var title = StripHtml(form.Title ?? $"Form {formId}");

        var doc = QuestPDF.Fluent.Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(QuestPDF.Helpers.PageSizes.A4.Landscape());
                page.Margin(20);
                page.DefaultTextStyle(x => x.FontSize(7));

                page.Header().Column(col =>
                {
                    col.Item().Text($"Responses - {title}").Bold().FontSize(14).FontColor(QuestPDF.Helpers.Colors.Grey.Darken3);
                    col.Item().Text($"Exported {DateTime.UtcNow:yyyy-MM-dd HH:mm} UTC • {responses.Count} responses • {questions.Count} questions").FontSize(8).FontColor(QuestPDF.Helpers.Colors.Grey.Medium);
                    col.Item().PaddingTop(4).LineHorizontal(1).LineColor(QuestPDF.Helpers.Colors.Grey.Lighten2);
                });

                page.Content().PaddingTop(10).Table(table =>
                {
                    table.ColumnsDefinition(cols =>
                    {
                        cols.RelativeColumn(0.5f);
                        cols.RelativeColumn(1f);
                        cols.RelativeColumn(1f);
                        foreach (var _ in questions) cols.RelativeColumn(1.5f);
                        cols.RelativeColumn(0.7f);
                    });

                    table.Header(header =>
                    {
                        foreach (var h in headers)
                        {
                            header.Cell().Element(CellHeader).Text(h).Bold().FontColor(QuestPDF.Helpers.Colors.White);
                        }

                        static QuestPDF.Infrastructure.IContainer CellHeader(QuestPDF.Infrastructure.IContainer c) =>
                            c.Background("#2A9D8F").PaddingVertical(4).PaddingHorizontal(4).DefaultTextStyle(x => x.FontSize(7));
                    });

                    foreach (var r in responses)
                    {
                        var vals = new List<string>
                        {
                            r.Id.ToString(),
                            r.SubmittedAt?.ToString("yyyy-MM-dd HH:mm") ?? "",
                            r.Respondent?.Fullname ?? r.RespondentName ?? "Anonymous",
                        };
                        foreach (var q in questions)
                        {
                            var answer = r.RespondentAnswers.FirstOrDefault(a => a.QuestionId == q.Id);
                            string val = "";
                            if (answer != null)
                                val = answer.OptionId.HasValue ? (answer.Option?.OptionText ?? "") : (answer.AnswerValue ?? "");
                            vals.Add(StripHtml(val));
                        }
                        vals.Add(r.Status?.Status ?? "unknown");

                        foreach (var v in vals)
                        {
                            table.Cell().Element(CellBody).Text(v.Length > 120 ? v[..120] + "..." : v);
                        }

                        static QuestPDF.Infrastructure.IContainer CellBody(QuestPDF.Infrastructure.IContainer c) =>
                            c.BorderBottom(0.5f).BorderColor(QuestPDF.Helpers.Colors.Grey.Lighten2).PaddingVertical(3).PaddingHorizontal(4);
                    }
                });

                page.Footer().AlignCenter().Text(x =>
                {
                    x.Span("FormUp • ").FontSize(7).FontColor(QuestPDF.Helpers.Colors.Grey.Medium);
                    x.Span("page ").FontSize(7);
                    x.CurrentPageNumber().FontSize(7);
                    x.Span(" / ").FontSize(7);
                    x.TotalPages().FontSize(7);
                });
            });
        });

        var pdf = doc.GeneratePdf();
        return File(pdf, "application/pdf", $"responses-form-{formId}.pdf");
    }

    private static string StripHtml(string? value)
    {
        if (string.IsNullOrEmpty(value)) return "";
        var clean = System.Text.RegularExpressions.Regex.Replace(value, "<.*?>", string.Empty);
        clean = System.Text.RegularExpressions.Regex.Replace(clean, @"[\r\n]+", " ").Trim();
        return clean;
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }

    private static string EscapeCsv(string? value)
    {
        if (string.IsNullOrEmpty(value)) return "\"\"";
        // Strip HTML tags and clean up internal line breaks
        var clean = System.Text.RegularExpressions.Regex.Replace(value, "<.*?>", string.Empty);
        clean = System.Text.RegularExpressions.Regex.Replace(clean, @"[\r\n]+", " ").Trim();
        return $"\"{clean.Replace("\"", "\"\"")}\"";
    }
}