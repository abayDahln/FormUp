using System.Text.Json;
using FormUpAPI.Models;
using Microsoft.Data.SqlClient;

namespace FormUpAPI.Services;

public class ErrorHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ErrorHandlingMiddleware> _logger;

    public ErrorHandlingMiddleware(RequestDelegate next, ILogger<ErrorHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task Invoke(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (SqlException ex)
        {
            // DB tidak aktif (mis. service SQL Server belum jalan) — pesan generik
            // agar user (bukan admin server) tidak diberi detail infrastruktur.
            _logger.LogError(ex, "Database unavailable on {Method} {Path}", context.Request.Method, context.Request.Path);

            if (context.Response.HasStarted)
                throw;

            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            context.Response.ContentType = "application/json";

            var apiResponse = new ApiResponse<object>(503, "Server sedang offline. Silakan coba lagi nanti.");
            await context.Response.WriteAsync(JsonSerializer.Serialize(apiResponse));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception on {Method} {Path}", context.Request.Method, context.Request.Path);

            if (context.Response.HasStarted)
                throw;

            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            context.Response.ContentType = "application/json";

            var apiResponse = new ApiResponse<object>(500, "Internal server error");
            await context.Response.WriteAsync(JsonSerializer.Serialize(apiResponse));
        }
    }
}
