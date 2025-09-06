using Serilog;
using CGIProxy.Middleware;
using CGIProxy.Services;

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/proxy-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);

// Add Serilog
builder.Host.UseSerilog();

// Add services
builder.Services.AddControllers();
builder.Services.AddRazorPages();
builder.Services.AddHealthChecks();
builder.Services.AddHttpClient();

// Add background services
builder.Services.AddSingleton<ProcessMonitorService>();
builder.Services.AddHostedService<ProcessMonitorService>(provider => provider.GetService<ProcessMonitorService>()!);

// Add YARP
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

// Add CORS for admin portal integration
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure middleware pipeline
app.UseSerilogRequestLogging();

// Add CORS
app.UseCors();

// Add custom request logging middleware
app.UseMiddleware<RequestLoggingMiddleware>();

// Add routing
app.UseRouting();

// Map controllers for metrics API
app.MapControllers();

// Map Razor pages for admin dashboard
app.MapRazorPages();

// Map health checks
app.MapHealthChecks("/health");

// Add YARP reverse proxy
app.MapReverseProxy();

// Handle root path
app.MapGet("/", () => new { 
    service = "CGI Proxy with Admin", 
    version = "1.0.0", 
    timestamp = DateTime.UtcNow,
    endpoints = new[] { 
        "/api/metrics", 
        "/api/process", 
        "/admin", 
        "/health", 
        "/api/search", 
        "/api/auth" 
    }
});

try
{
    Log.Information("🚀 Starting YARP CGI Proxy");
    Log.Information("Metrics API available at /api/metrics");
    Log.Information("Health check available at /health");
    
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "💥 Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
