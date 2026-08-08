# Deployment Guide

## Prerequisites

- .NET 8.0 SDK
- SQL Server 2019+
- Environment variables:

| Variable | Required | Description |
|----------|----------|-------------|
| `JWT_KEY` | Yes | Secret key minimum 32 characters |
| `DB_CONNECTION` | Yes | SQL Server connection string |

## Local Development

```bash
# Set user secrets (development only)
dotnet user-secrets init
dotnet user-secrets set "Jwt:Key" "your-super-secret-key-at-least-32-characters"
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "server=localhost;database=FormUpDB;trusted_connection=true;TrustServerCertificate=true"

# Run database migrations
dotnet ef database update

# Start API
dotnet run --launch-profile http
```

## Production Deployment

1. **Set environment variables** (do NOT use appsettings.json for secrets):
   ```bash
   export JWT_KEY="your-production-secret-key"
   export DB_CONNECTION="Server=prod-db;Database=FormUpDB;User Id=app;Password=***;TrustServerCertificate=true"
   ```   

2. **Publish application**:
   ```bash
   dotnet publish -c Release -o ./publish
   ```

3. **Configure reverse proxy** (Nginx/IIS) with HTTPS termination

4. **Update AllowedOrigins** in appsettings.json with your frontend domain

## Environment-based Configuration

- `ASPNETCORE_ENVIRONMENT=Development` → Uses user secrets, relaxed HTTPS
- `ASPNETCORE_ENVIRONMENT=Production` → Requires HTTPS metadata, strict CORS
