using Serilog;
using CGIProxy.Middleware;

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/proxy-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);

// Check for required configuration
var configPath = Path.Combine(Directory.GetCurrentDirectory(), "appsettings.json");
if (!File.Exists(configPath))
{
    Console.Error.WriteLine("❌ CONFIGURATION ERROR: appsettings.json not found");
    Console.Error.WriteLine($"   Expected path: {configPath}");
    Console.Error.WriteLine();
    Console.Error.WriteLine("🔧 To fix this issue:");
    Console.Error.WriteLine("   1. Run 'make generate-proxy-config' to generate the configuration");
    Console.Error.WriteLine("   2. Or run 'make run-yarp' which includes configuration generation");
    Console.Error.WriteLine();
    Console.Error.WriteLine("💡 The configuration is generated from discovery/manifest.json");
    Environment.Exit(1);
}

// Validate YARP configuration exists
var reverseProxySection = builder.Configuration.GetSection("ReverseProxy");
if (!reverseProxySection.Exists())
{
    Console.Error.WriteLine("❌ CONFIGURATION ERROR: ReverseProxy section missing from appsettings.json");
    Console.Error.WriteLine();
    Console.Error.WriteLine("🔧 To fix this issue:");
    Console.Error.WriteLine("   1. Delete the current appsettings.json file");
    Console.Error.WriteLine("   2. Run 'make generate-proxy-config' to regenerate the configuration");
    Console.Error.WriteLine("   3. Or run 'make run-yarp' which includes configuration generation");
    Environment.Exit(1);
}

// Add Serilog
builder.Host.UseSerilog();

// Add services
builder.Services.AddControllers();
builder.Services.AddRazorPages();
builder.Services.AddHealthChecks();
builder.Services.AddHttpClient();

// Add background services (removed for now)

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
    service = "CGI Proxy with Dynamic Discovery", 
    version = "1.1.0", 
    timestamp = DateTime.UtcNow,
    note = "Endpoints dynamically generated at build time from manifest.json"
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
