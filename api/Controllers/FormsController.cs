using System.Security.Claims;
using FormUpAPI.Models;
using FormUpAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using QRCoder;

namespace FormUpAPI.Controllers;

[Route("api/[controller]")]
[ApiController]
[EnableRateLimiting("creator")]
[Authorize]
public class FormsController : ControllerBase
{
    private readonly FormUpDbContext _db;
    private readonly IConfiguration _config;

    public FormsController(FormUpDbContext db, IConfiguration config)
    {
        _db = db;
        _config = config;
    }

    private string PublicBaseUrl
    {
        get
        {
            var url = Environment.GetEnvironmentVariable("PUBLIC_URL");
            if (string.IsNullOrWhiteSpace(url))
                url = _config["PublicUrl"];
            return string.IsNullOrWhiteSpace(url)
                ? $"{Request.Scheme}://{Request.Host}"
                : url;
        }
    }

    private static DateTime? NormalizeToUtc(DateTime? value)
    {
        if (!value.HasValue || value.Value == DateTime.MinValue)
            return null;

        var v = value.Value;
        return v.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(v, DateTimeKind.Utc)
            : v.ToUniversalTime();
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<object>>> GetAll()
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var forms = await _db.Forms
            .Include(f => f.Status)
            .Where(f => f.UserId == user.Id && f.DeletedAt == null)
            .OrderByDescending(f => f.UpdatedAt)
            .Select(f => new FormResponse
            {
                Id = f.Id,
                Title = f.Title,
                Description = f.Description,
                DescriptionFormat = f.DescriptionFormat,
                BannerImage = f.BannerImage,
                FormLink = f.FormLink,
                Status = f.Status!.Status,
                ResponseCount = f.Responses.Count,
                CreatedAt = f.CreatedAt,
                UpdatedAt = f.UpdatedAt,
            })
            .ToListAsync();

        foreach (var f in forms)
            f.DescriptionFormat ??= RichTextValidation.FormatOf(f.Description);

        return Ok(new ApiResponse<object>(200, "OK", forms));
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> GetById(int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .Include(f => f.Status)
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == id && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        return Ok(new ApiResponse<object>(200, "OK", new FormDetailResponse
        {
            Id = form.Id,
            Title = form.Title,
            Description = form.Description,
            DescriptionFormat = form.DescriptionFormat ?? RichTextValidation.FormatOf(form.Description),
            BannerImage = form.BannerImage,
            FormLink = form.FormLink,
            Status = form.Status?.Status ?? "unknown",
            ResponseCount = await _db.Responses.CountAsync(r => r.FormId == form.Id),
            Settings = form.FormSetting == null ? null : new FormSettingDto
            {
                FormTypeId = form.FormSetting.FormTypeId,
                ShowScore = form.FormSetting.ShowScore,
                RandomizeQuestions = form.FormSetting.RandomizeQuestions,
                FormToken = form.FormSetting.FormToken,
                TimerDuration = form.FormSetting.TimerDuration,
                OneResponse = form.FormSetting.OneResponse,
                RequiredLogin = form.FormSetting.RequiredLogin,
                OpenFormTime = form.FormSetting.OpenFormTime,
                CloseFormTime = form.FormSetting.CloseFormTime,
            },
            CreatedAt = form.CreatedAt,
            UpdatedAt = form.UpdatedAt,
        }));
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == id && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        form.DeletedAt = JakartaTime.Now;
        form.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Form deleted"));
    }

    [HttpPost("bulk-delete")]
    public async Task<ActionResult<ApiResponse<object>>> BulkDelete([FromBody] BulkDeleteFormsRequest request)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        if (request.FormIds == null || request.FormIds.Count == 0)
            return BadRequest(new ApiResponse<object>(400, "No form IDs provided"));

        var forms = await _db.Forms
            .Where(f => request.FormIds.Contains(f.Id) && f.UserId == user.Id && f.DeletedAt == null)
            .ToListAsync();

        var now = JakartaTime.Now;
        foreach (var form in forms)
        {
            form.DeletedAt = now;
            form.UpdatedAt = now;
        }

        await _db.SaveChangesAsync();
        return Ok(new ApiResponse<object>(200, $"{forms.Count} forms deleted"));
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Update(int id, [FromBody] UpdateFormRequest request)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .Include(f => f.Status)
            .FirstOrDefaultAsync(f => f.Id == id && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        if (request.Title != null)
        {
            if (string.IsNullOrWhiteSpace(request.Title))
                return BadRequest(new ApiResponse<object>(400, "Title cannot be empty"));
            form.Title = request.Title;
        }

        if (request.Description != null)
        {
            if (!RichTextValidation.TryValidate(request.Description, out var descError))
                return BadRequest(new ApiResponse<object>(400, descError ?? "Deskripsi tidak valid"));
            form.Description = request.Description;
            form.DescriptionFormat = RichTextValidation.FormatOf(request.Description);
        }

        if (request.BannerImage != null)
            form.BannerImage = request.BannerImage;

        if (request.FormLink != null)
        {
            var newLink = request.FormLink.Trim().ToLowerInvariant().Replace(' ', '-');
            if (newLink.Length < 3 || newLink.Length > 100 ||
                !System.Text.RegularExpressions.Regex.IsMatch(newLink, "^[a-z0-9]+(?:-[a-z0-9]+)*$"))
                return BadRequest(new ApiResponse<object>(400, "Form link hanya boleh huruf kecil, angka, dan tanda strip (-), tanpa spasi, minimal 3 karakter"));

            var clash = await _db.Forms.AnyAsync(f => f.FormLink == newLink && f.Id != form.Id);
            if (clash)
                return Conflict(new ApiResponse<object>(409, "Form link sudah dipakai form lain"));

            form.FormLink = newLink;
        }

        form.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Form updated", MapFormResponse(form)));
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<object>>> Create([FromBody] CreateFormRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
            return BadRequest(new ApiResponse<object>(400, "Title is required"));

        if (request.Description != null && !RichTextValidation.TryValidate(request.Description, out var descError))
            return BadRequest(new ApiResponse<object>(400, descError ?? "Deskripsi tidak valid"));

        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var draftStatus = await _db.FormStatuses.FirstOrDefaultAsync(s => s.Status == "draft");
        if (draftStatus == null)
            return StatusCode(500, new ApiResponse<object>(500, "Draft status not found"));

        var form = new Form
        {
            UserId = user.Id,
            StatusId = draftStatus.Id,
            Title = request.Title,
            Description = request.Description,
            DescriptionFormat = RichTextValidation.FormatOf(request.Description),
            BannerImage = request.BannerImage,
            FormLink = Guid.NewGuid().ToString("N")[..12],
            CreatedAt = JakartaTime.Now,
        };

        _db.Forms.Add(form);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = form.Id }, new ApiResponse<object>(201, "Form created", MapFormResponse(form)));
    }

    [HttpPost("{id}/banner")]
    public async Task<ActionResult<ApiResponse<object>>> UploadBanner(int id, IFormFile? file)
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
            .FirstOrDefaultAsync(f => f.Id == id && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var uniqueName = $"{Guid.NewGuid()}{ext}";
        var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "banner");
        Directory.CreateDirectory(uploadDir);
        var filePath = Path.Combine(uploadDir, uniqueName);

        ms.Position = 0;
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await ms.CopyToAsync(stream);
        }

        if (!string.IsNullOrEmpty(form.BannerImage))
        {
            var oldPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", form.BannerImage.TrimStart('/'));
            if (System.IO.File.Exists(oldPath))
                System.IO.File.Delete(oldPath);
        }

        form.BannerImage = $"/banner/{uniqueName}";
        form.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Banner uploaded", new { bannerImage = form.BannerImage }));
    }

    [HttpPatch("{id}/settings")]
    public async Task<ActionResult<ApiResponse<object>>> UpdateSettings(int id, [FromBody] UpdateFormSettingsRequest request)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == id && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        if (form.FormSetting == null)
        {
            form.FormSetting = new FormSetting
            {
                FormId = form.Id,
                FormTypeId = 1,
                CreatedAt = JakartaTime.Now,
            };
            _db.FormSettings.Add(form.FormSetting);
        }

        if (request.ShowScore.HasValue)
            form.FormSetting.ShowScore = request.ShowScore.Value;

        if (request.RandomizeQuestions.HasValue)
            form.FormSetting.RandomizeQuestions = request.RandomizeQuestions.Value;

        if (request.FormToken != null)
            form.FormSetting.FormToken = request.FormToken;

        if (request.TimerDuration.HasValue)
            form.FormSetting.TimerDuration = request.TimerDuration.Value;

        if (request.OneResponse.HasValue)
            form.FormSetting.OneResponse = request.OneResponse.Value;

        if (request.RequiredLogin.HasValue)
            form.FormSetting.RequiredLogin = request.RequiredLogin.Value;

        if (request.OpenFormTime.HasValue)
        {
            form.FormSetting.OpenFormTime = NormalizeToUtc(request.OpenFormTime);
        }

        if (request.CloseFormTime.HasValue)
        {
            form.FormSetting.CloseFormTime = NormalizeToUtc(request.CloseFormTime);
        }

        if (request.FormTypeId.HasValue)
        {
            var typeExists = await _db.FormTypes.AnyAsync(t => t.Id == request.FormTypeId.Value);
            if (!typeExists)
                return BadRequest(new ApiResponse<object>(400, "Invalid form type ID"));
            form.FormSetting.FormTypeId = request.FormTypeId.Value;
        }

        form.FormSetting.UpdatedAt = JakartaTime.Now;
        form.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Settings updated", new FormSettingDto
        {
            FormTypeId = form.FormSetting.FormTypeId,
            ShowScore = form.FormSetting.ShowScore,
            RandomizeQuestions = form.FormSetting.RandomizeQuestions,
            FormToken = form.FormSetting.FormToken,
            TimerDuration = form.FormSetting.TimerDuration,
            OneResponse = form.FormSetting.OneResponse,
            RequiredLogin = form.FormSetting.RequiredLogin,
            OpenFormTime = form.FormSetting.OpenFormTime,
            CloseFormTime = form.FormSetting.CloseFormTime,
        }));
    }

    [HttpPost("{id}/publish")]
    public async Task<ActionResult<ApiResponse<object>>> Publish(int id)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .Include(f => f.Status)
            .FirstOrDefaultAsync(f => f.Id == id && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var draftStatus = await _db.FormStatuses.FirstAsync(s => s.Status == "draft");
        var publishedStatus = await _db.FormStatuses.FirstAsync(s => s.Status == "published");

        if (form.StatusId == publishedStatus.Id)
        {
            form.StatusId = draftStatus.Id;
            form.UpdatedAt = JakartaTime.Now;
            await _db.SaveChangesAsync();
            return Ok(new ApiResponse<object>(200, "Form unpublished"));
        }

        // Form tanpa soal tidak boleh dipublish
        var questionCount = await _db.Questions.CountAsync(q => q.FormId == form.Id && q.DeletedAt == null);
        if (questionCount == 0)
            return BadRequest(new ApiResponse<object>(400,
                "Form tidak dapat dipublish karena belum memiliki soal"));

        form.StatusId = publishedStatus.Id;
        form.UpdatedAt = JakartaTime.Now;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(200, "Form published"));
    }

    [HttpGet("{formId}/share")]
    public async Task<ActionResult<ApiResponse<object>>> Share(int formId)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .Include(f => f.FormSetting)
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var baseUrl = PublicBaseUrl;
        var qrUrl = $"{baseUrl}/api/forms/{formId}/share/qr";

        return Ok(new ApiResponse<object>(200, "OK", new ShareInfoResponse
        {
            FormLink = form.FormLink,
            ShareUrl = $"{baseUrl}/f/{form.FormLink}",
            RequiresToken = !string.IsNullOrEmpty(form.FormSetting?.FormToken),
            HasToken = !string.IsNullOrEmpty(form.FormSetting?.FormToken),
            QrCodeUrl = qrUrl,
        }));
    }

    [HttpGet("{formId}/share/qr")]
    public async Task<IActionResult> ShareQr(int formId)
    {
        var user = await GetCurrentUser();
        if (user == null)
            return Unauthorized(new ApiResponse<object>(401, "User not found"));

        var form = await _db.Forms
            .FirstOrDefaultAsync(f => f.Id == formId && f.UserId == user.Id && f.DeletedAt == null);

        if (form == null)
            return NotFound(new ApiResponse<object>(404, "Form not found"));

        var baseUrl = PublicBaseUrl;
        var shareUrl = $"{baseUrl}/f/{form.FormLink}";

        using var gen = new QRCodeGenerator();
        var data = gen.CreateQrCode(shareUrl, QRCodeGenerator.ECCLevel.Q);
        using var png = new PngByteQRCode(data);
        var bytes = png.GetGraphic(20);

        return File(bytes, "image/png");
    }

    private async Task<User?> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
            return null;

        return await _db.Users.FindAsync(userId);
    }

    private static FormResponse MapFormResponse(Form form) => new()
    {
        Id = form.Id,
        Title = form.Title,
        Description = form.Description,
        DescriptionFormat = form.DescriptionFormat ?? RichTextValidation.FormatOf(form.Description),
        BannerImage = form.BannerImage,
        FormLink = form.FormLink,
        Status = form.Status?.Status ?? "unknown",
        CreatedAt = form.CreatedAt,
        UpdatedAt = form.UpdatedAt,
    };
}