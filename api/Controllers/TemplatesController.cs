using ClosedXML.Excel;
using DocumentFormat.OpenXml.Packaging;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace FormUpAPI.Controllers;

[Route("api/templates")]
[ApiController]
[EnableRateLimiting("template")]
public class TemplatesController : ControllerBase
{
    [HttpGet("import-questions")]
    public IActionResult DownloadTemplate([FromQuery] string format = "csv")
    {
        return format.ToLowerInvariant() switch
        {
            "csv" => DownloadCsv(),
            "xlsx" => DownloadXlsx(),
            "docx" => DownloadDocx(),
            "pdf" => DownloadPdf(),
            _ => BadRequest(new { status = 400, message = "Supported formats: csv, xlsx, docx, pdf" }),
        };
    }

    private IActionResult DownloadCsv()
    {
        var csv = "question,type_id,order,is_required,randomize_options,correct_answer,options" + Environment.NewLine +
                  "Apa warna langit?,2,1,TRUE,FALSE,Biru,Biru|Hijau|Merah" + Environment.NewLine +
                  "Siapa presiden pertama RI?,2,2,TRUE,FALSE,Soekarno,Soekarno|Hatta|Suharto" + Environment.NewLine +
                  "2+2 berapa?,1,3,TRUE,FALSE,4," + Environment.NewLine +
                  "Jelaskan dampak pemanasan global,1,4,FALSE,FALSE,,";

        return File(System.Text.Encoding.UTF8.GetBytes(csv), "text/csv", "import-questions-template.csv");
    }

    private IActionResult DownloadXlsx()
    {
        using var workbook = new XLWorkbook();
        var sheet = workbook.Worksheets.Add("Questions");

        sheet.Cell(1, 1).Value = "question";
        sheet.Cell(1, 2).Value = "type_id";
        sheet.Cell(1, 3).Value = "order";
        sheet.Cell(1, 4).Value = "is_required";
        sheet.Cell(1, 5).Value = "randomize_options";
        sheet.Cell(1, 6).Value = "correct_answer";
        sheet.Cell(1, 7).Value = "options";

        sheet.Cell(2, 1).Value = "Apa warna langit?";
        sheet.Cell(2, 2).Value = 2;
        sheet.Cell(2, 3).Value = 1;
        sheet.Cell(2, 4).Value = "TRUE";
        sheet.Cell(2, 5).Value = "FALSE";
        sheet.Cell(2, 6).Value = "Biru";
        sheet.Cell(2, 7).Value = "Biru|Hijau|Merah";

        sheet.Cell(3, 1).Value = "Siapa presiden pertama RI?";
        sheet.Cell(3, 2).Value = 2;
        sheet.Cell(3, 3).Value = 2;
        sheet.Cell(3, 4).Value = "TRUE";
        sheet.Cell(3, 5).Value = "FALSE";
        sheet.Cell(3, 6).Value = "Soekarno";
        sheet.Cell(3, 7).Value = "Soekarno|Hatta|Suharto";

        sheet.Cell(4, 1).Value = "2+2 berapa?";
        sheet.Cell(4, 2).Value = 1;
        sheet.Cell(4, 3).Value = 3;
        sheet.Cell(4, 4).Value = "TRUE";
        sheet.Cell(4, 5).Value = "FALSE";
        sheet.Cell(4, 6).Value = "4";
        sheet.Cell(4, 7).Value = "";

        sheet.Cell(5, 1).Value = "Jelaskan dampak pemanasan global";
        sheet.Cell(5, 2).Value = 1;
        sheet.Cell(5, 3).Value = 4;
        sheet.Cell(5, 4).Value = "FALSE";
        sheet.Cell(5, 5).Value = "FALSE";
        sheet.Cell(5, 6).Value = "";
        sheet.Cell(5, 7).Value = "";

        sheet.Columns().AdjustToContents();

        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        stream.Position = 0;
        return File(stream.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "import-questions-template.xlsx");
    }

    private IActionResult DownloadDocx()
    {
        using var stream = new MemoryStream();
        using var doc = WordprocessingDocument.Create(stream, DocumentFormat.OpenXml.WordprocessingDocumentType.Document);
        var mainPart = doc.AddMainDocumentPart();
        mainPart.Document = new DocumentFormat.OpenXml.Wordprocessing.Document();
        var body = mainPart.Document.AppendChild(new DocumentFormat.OpenXml.Wordprocessing.Body());

        var lines = new[]
        {
            "Question: Apa warna langit?",
            "Options: Biru | Hijau | Merah",
            "Type ID: 2",
            "Is Required: true",
            "Correct Answer: Biru",
            "",
            "Question: Siapa presiden pertama RI?",
            "Options: Soekarno | Hatta | Suharto",
            "Type ID: 2",
            "Is Required: true",
            "Correct Answer: Soekarno",
            "",
            "Question: 2+2 berapa?",
            "Type ID: 1",
            "Is Required: true",
            "Correct Answer: 4",
            "",
            "Question: Jelaskan dampak pemanasan global",
            "Type ID: 1",
        };

        foreach (var line in lines)
        {
            if (string.IsNullOrEmpty(line))
            {
                body.AppendChild(new DocumentFormat.OpenXml.Wordprocessing.Paragraph());
                continue;
            }
            var para = body.AppendChild(new DocumentFormat.OpenXml.Wordprocessing.Paragraph());
            var run = para.AppendChild(new DocumentFormat.OpenXml.Wordprocessing.Run());
            run.AppendChild(new DocumentFormat.OpenXml.Wordprocessing.Text(line));
        }

        doc.Save();
        stream.Position = 0;
        return File(stream.ToArray(), "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "import-questions-template.docx");
    }

    private IActionResult DownloadPdf()
    {
        QuestPDF.Settings.License = LicenseType.Community;

        var pdfDoc = QuestPDF.Fluent.Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(30);
                page.DefaultTextStyle(x => x.FontSize(11));

                page.Content().Column(col =>
                {
                    col.Item().Text("Template Import Soal").Bold().FontSize(16);
                    col.Item().Text("Format: type_id, options (pipe-separated)").FontSize(10).FontColor(Colors.Grey.Medium);
                    col.Item().LineHorizontal(1);
                    col.Item().Text("");

                    var rows = new[]
                    {
                        ("Question: Apa warna langit?", "Options: Biru | Hijau | Merah", "Type ID: 1, Required: true"),
                        ("Question: Siapa presiden pertama RI?", "Options: Soekarno | Hatta | Suharto", "Type ID: 1, Required: true, Answer: Soekarno"),
                        ("Question: 2+2 berapa?", "", "Type ID: 3, Required: true, Answer: 4"),
                        ("Question: Jelaskan dampak pemanasan global", "", "Type ID: 4"),
                    };

                    foreach (var (q, opts, meta) in rows)
                    {
                        col.Item().Text(q).Bold();
                        if (!string.IsNullOrEmpty(opts))
                            col.Item().Text(opts).FontColor(Colors.Blue.Medium);
                        col.Item().Text(meta).FontSize(9).FontColor(Colors.Grey.Medium);
                        col.Item().Text("");
                    }

                    col.Item().LineHorizontal(1);
                    col.Item().Text("Petunjuk:").Bold();
                    col.Item().Text("• Baris kosong = pemisah antar soal");
                    col.Item().Text("• Format metadata: Type ID: 1, Is Required: true, Correct Answer: ...");
                    col.Item().Text("• Opsi bisa ditulis sebagai: Options: A | B | C atau per baris dengan awalan - ");
                });
            });
        });

        var pdf = pdfDoc.GeneratePdf();
        return File(pdf, "application/pdf", "import-questions-template.pdf");
    }
}