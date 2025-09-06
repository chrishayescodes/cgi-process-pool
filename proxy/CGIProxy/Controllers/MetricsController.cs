using Microsoft.AspNetCore.Mvc;
using CGIProxy.Middleware;

namespace CGIProxy.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MetricsController : ControllerBase
{
    private readonly ILogger<MetricsController> _logger;

    public MetricsController(ILogger<MetricsController> logger)
    {
        _logger = logger;
    }

    [HttpGet]
    public IActionResult GetMetrics()
    {
        var metrics = RequestLoggingMiddleware.GetMetrics();
        return Ok(metrics);
    }

    [HttpGet("requests")]
    public IActionResult GetRecentRequests([FromQuery] int limit = 100)
    {
        var requests = RequestLoggingMiddleware.GetRecentRequests();
        var limitedRequests = requests.TakeLast(limit).Reverse().ToList();
        
        return Ok(new 
        { 
            requests = limitedRequests,
            total = requests.Count
        });
    }

    [HttpGet("requests/live")]
    public IActionResult GetLiveRequests([FromQuery] int seconds = 30)
    {
        var cutoff = DateTime.UtcNow.AddSeconds(-seconds);
        var requests = RequestLoggingMiddleware.GetRecentRequests()
            .Where(r => r.Timestamp > cutoff)
            .OrderByDescending(r => r.Timestamp)
            .ToList();
        
        return Ok(new 
        { 
            requests,
            timeWindow = $"Last {seconds} seconds",
            count = requests.Count
        });
    }

    [HttpPost("requests/clear")]
    public IActionResult ClearRequests()
    {
        RequestLoggingMiddleware.ClearRequests();
        _logger.LogInformation("Request metrics cleared");
        return Ok(new { message = "Request metrics cleared" });
    }

    [HttpGet("health")]
    public IActionResult HealthCheck()
    {
        return Ok(new 
        { 
            status = "healthy",
            timestamp = DateTime.UtcNow,
            service = "YARP Proxy",
            version = "1.0.0"
        });
    }

    [HttpGet("summary")]
    public IActionResult GetSummary()
    {
        var metrics = RequestLoggingMiddleware.GetMetrics();
        var requests = RequestLoggingMiddleware.GetRecentRequests();
        
        var summary = new
        {
            proxy = new
            {
                uptime = DateTime.UtcNow,
                totalRequests = metrics["totalRequests"],
                requestsPerMinute = metrics["requestsPerMinute"],
                averageResponseTime = metrics["averageResponseTime"]
            },
            services = new
            {
                search = requests.Count(r => r.Service == "search"),
                auth = requests.Count(r => r.Service == "auth"),
                admin = requests.Count(r => r.Service == null && r.Path.StartsWith("/admin"))
            },
            performance = new
            {
                fastRequests = requests.Count(r => r.ResponseTimeMs < 100),
                slowRequests = requests.Count(r => r.ResponseTimeMs > 1000),
                averageResponseTime = requests.Any() ? requests.Average(r => r.ResponseTimeMs) : 0
            },
            errors = new
            {
                total4xx = requests.Count(r => r.StatusCode >= 400 && r.StatusCode < 500),
                total5xx = requests.Count(r => r.StatusCode >= 500),
                successRate = requests.Count > 0 ? 
                    (double)requests.Count(r => r.StatusCode < 400) / requests.Count * 100 : 100
            }
        };

        return Ok(summary);
    }
}