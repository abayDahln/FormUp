using FormUpAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Controllers;

[Route("api/references")]
[ApiController]
[Authorize]
public class ReferencesController : ControllerBase
{
    private readonly FormUpDbContext _db;

    public ReferencesController(FormUpDbContext db)
    {
        _db = db;
    }

    [HttpGet("form-types")]
    public async Task<ActionResult<ApiResponse<object>>> GetFormTypes()
    {
        var items = await _db.FormTypes
            .OrderBy(t => t.Id)
            .Select(t => new { t.Id, t.Type })
            .ToListAsync();
        return Ok(new ApiResponse<object>(200, "OK", items));
    }

    [HttpGet("form-statuses")]
    public async Task<ActionResult<ApiResponse<object>>> GetFormStatuses()
    {
        var items = await _db.FormStatuses
            .OrderBy(s => s.Id)
            .Select(s => new { s.Id, s.Status })
            .ToListAsync();
        return Ok(new ApiResponse<object>(200, "OK", items));
    }

    [HttpGet("question-types")]
    public async Task<ActionResult<ApiResponse<object>>> GetQuestionTypes()
    {
        var items = await _db.QuestionTypes
            .OrderBy(q => q.Id)
            .Select(q => new { q.Id, q.Type })
            .ToListAsync();
        return Ok(new ApiResponse<object>(200, "OK", items));
    }
}
