
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using FormUpAPI.Models;
using FormUpAPI.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

namespace FormUpAPI
{
    public class Program
    {
        public static void Main(string[] args)
        {
            DotNetEnv.Env.Load();
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.
            var connString = Environment.GetEnvironmentVariable("DB_CONNECTION")
                ?? builder.Configuration.GetConnectionString("DefaultConnection");
            if (string.IsNullOrEmpty(connString))
                throw new InvalidOperationException("Database connection string is not configured. Set DB_CONNECTION environment variable or DefaultConnection in appsettings.json.");
            builder.Services.AddDbContext<FormUpDbContext>(options =>
                options.UseSqlServer(connString));

            builder.Services.AddControllers()
                .ConfigureApiBehaviorOptions(options =>
                {
                    options.InvalidModelStateResponseFactory = context =>
                    {
                        var errors = context.ModelState
                            .Where(kv => kv.Value?.Errors.Count > 0)
                            .ToDictionary(
                                kv => kv.Key,
                                kv => kv.Value!.Errors.Select(e => e.ErrorMessage).ToArray());
                        return new BadRequestObjectResult(new ApiResponse<object>(400, "Validation failed", errors));
                    };
                })
                .AddJsonOptions(options =>
                {
                    options.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
                    options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
                });


            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(c =>
            {
                c.SwaggerDoc("v1", new OpenApiInfo { Title = "FormUp API", Version = "v1" });

                var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
                var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
                if (File.Exists(xmlPath))
                {
                    c.IncludeXmlComments(xmlPath);
                }

                c.UseOneOfForPolymorphism();
                c.UseAllOfForInheritance();

                c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
                {
                    Description = "JWT Authorization header using the Bearer scheme. Example: \"Authorization: Bearer {token}\"",
                    Name = "Authorization",
                    In = ParameterLocation.Header,
                    Type = SecuritySchemeType.ApiKey,
                    Scheme = "Bearer"
                });

                c.AddSecurityRequirement(new OpenApiSecurityRequirement
                {
                    {
                        new OpenApiSecurityScheme
                        {
                            Reference = new OpenApiReference
                            {
                                Type = ReferenceType.SecurityScheme,
                                Id = "Bearer"
                            }
                        },
                        Array.Empty<string>()
                    }
                });
            });

            var jwtSettings = builder.Configuration.GetSection("Jwt");

            var keyString = Environment.GetEnvironmentVariable("JWT_KEY")
                ?? jwtSettings["Key"];
            if (string.IsNullOrEmpty(keyString))
                throw new InvalidOperationException("JWT Key is not configured. Set JWT_KEY environment variable or Jwt:Key in appsettings.json.");
            var key = Encoding.ASCII.GetBytes(keyString);

            var expiryMinutes = int.TryParse(jwtSettings["AccessTokenMinutes"], out var exp) ? exp : 60;

            builder.Services.AddAuthentication(op =>
            {
                op.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                op.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
            }).AddJwtBearer(op =>
            {
                op.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
                op.SaveToken = true;
                op.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(key),
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidIssuer = jwtSettings["Issuer"],
                    ValidAudience = jwtSettings["Audience"],
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.Zero
                };
                op.Events = new JwtBearerEvents
                {
                    OnAuthenticationFailed = context =>
                    {
                        if (context.Exception.GetType() == typeof(SecurityTokenExpiredException))
                        {
                            context.Response.Headers["Token-Expired"] = "true";
                        }
                        return Task.CompletedTask;
                    },
                    OnChallenge = context =>
                    {
                        context.HandleResponse();
                        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                        context.Response.ContentType = "application/json";

                        var apiResponse = new ApiResponse<object>(401, "Unauthorized");
                        var json = System.Text.Json.JsonSerializer.Serialize(apiResponse);
                        return context.Response.WriteAsync(json);
                    },
                    OnForbidden = context =>
                    {
                        context.Response.StatusCode = StatusCodes.Status403Forbidden;
                        context.Response.ContentType = "application/json";

                        var apiResponse = new ApiResponse<object>(403, "Forbidden");
                        var json = System.Text.Json.JsonSerializer.Serialize(apiResponse);
                        return context.Response.WriteAsync(json);
                    }
                };

            });

            builder.Services.AddSingleton<JwtService>();
            builder.Services.AddSingleton<EmailService>();
            builder.Services.AddAuthorization();

            builder.Services.AddRateLimiter(options =>
            {
                options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
                options.OnRejected = async (context, ct) =>
                {
                    context.HttpContext.Response.ContentType = "application/json";
                    var apiResponse = new ApiResponse<object>(429, "Too many requests. Please try again later.");
                    await context.HttpContext.Response.WriteAsync(System.Text.Json.JsonSerializer.Serialize(apiResponse), ct);
                };

                // Endpoint auth (login/register/refresh/OTP): paling ketat.
                options.AddFixedWindowLimiter("auth", o =>
                {
                    o.PermitLimit = 10;
                    o.Window = TimeSpan.FromMinutes(1);
                    o.QueueLimit = 0;
                });

                // Manajemen form (form creator): sedang.
                options.AddPolicy("creator", context =>
                {
                    var key = context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                        ?? context.Connection.RemoteIpAddress?.ToString()
                        ?? "anon";
                    return RateLimitPartition.GetSlidingWindowLimiter(key, _ => new SlidingWindowRateLimiterOptions
                    {
                        PermitLimit = 120,
                        Window = TimeSpan.FromMinutes(1),
                        SegmentsPerWindow = 4,
                        QueueLimit = 0,
                    });
                });

                // Submit form publik: longgar + berbasis kombinasi form+IP (bukan cuma IP).
                options.AddPolicy("submit", context =>
                {
                    var formId = context.Request.RouteValues["formId"]?.ToString() ?? "0";
                    var key = $"{context.Connection.RemoteIpAddress}:{formId}";
                    return RateLimitPartition.GetSlidingWindowLimiter(key, _ => new SlidingWindowRateLimiterOptions
                    {
                        PermitLimit = 60,
                        Window = TimeSpan.FromMinutes(1),
                        SegmentsPerWindow = 4,
                        QueueLimit = 0,
                    });
                });
            });

            var allowedOrigins = builder.Configuration.GetSection("AllowedOrigins").Get<string[]>() ?? [];
            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AllowFrontend", policy =>
                {
                    policy.WithOrigins(allowedOrigins)
                          .AllowAnyMethod()
                          .AllowAnyHeader()
                          .AllowCredentials();
                });
            });

            var app = builder.Build();


            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI(c =>
                {
                    c.SwaggerEndpoint("/swagger/v1/swagger.json", "FormUp API v1");
                    c.ConfigObject.AdditionalItems.Add("persistAuthorization", "true");
                    c.RoutePrefix = "swagger";
                });
            }
            app.UseStaticFiles();
            app.UseMiddleware<ErrorHandlingMiddleware>();
            app.UseCors("AllowFrontend");
            app.UseHttpsRedirection();

            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();


            app.MapControllers();

            app.Run();
        }
    }
}
