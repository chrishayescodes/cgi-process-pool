using System.Diagnostics;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.SignalR.Client;

namespace CGIProxy.Middleware;

public class RequestMetric
{
    public string RequestId { get; set; } = Guid.NewGuid().ToString();
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public string Method { get; set; } = string.Empty;
    public string Path { get; set; } = string.Empty;
    public string? QueryString { get; set; }
    public int StatusCode { get; set; }
    public long ResponseTimeMs { get; set; }
    public string? Service { get; set; }
    public string? Destination { get; set; }
    public string ClientIP { get; set; } = string.Empty;
    public string UserAgent { get; set; } = string.Empty;
    public long RequestSize { get; set; }
    public long ResponseSize { get; set; }
}

public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestLoggingMiddleware> _logger;
    private static readonly List<RequestMetric> _recentRequests = new();
    private static readonly object _lock = new object();
    private const int MaxRecentRequests = 1000;

    public RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();
        var requestMetric = new RequestMetric
        {
            Method = context.Request.Method,
            Path = context.Request.Path,
            QueryString = context.Request.QueryString.ToString(),
            ClientIP = context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            UserAgent = context.Request.Headers.UserAgent.ToString() ?? "unknown",
            RequestSize = context.Request.ContentLength ?? 0
        };

        // Capture the original response body stream
        var originalBodyStream = context.Response.Body;
        using var responseBodyStream = new MemoryStream();
        context.Response.Body = responseBodyStream;

        try
        {
            // Get service info from route path
            if (context.Request.Path.StartsWithSegments("/api/search"))
            {
                requestMetric.Service = "search";
            }
            else if (context.Request.Path.StartsWithSegments("/api/auth"))
            {
                requestMetric.Service = "auth";
            }
            else if (context.Request.Path.StartsWithSegments("/admin"))
            {
                requestMetric.Service = "admin";
            }

            // Get destination from YARP features
            var proxyFeature = context.Features.Get<Yarp.ReverseProxy.Forwarder.ForwarderRequestConfig>();
            if (proxyFeature != null)
            {
                requestMetric.Destination = "yarp-proxy";
            }

            await _next(context);

            stopwatch.Stop();
            requestMetric.StatusCode = context.Response.StatusCode;
            requestMetric.ResponseTimeMs = stopwatch.ElapsedMilliseconds;
            requestMetric.ResponseSize = responseBodyStream.Length;

            // Copy response back to original stream
            responseBodyStream.Position = 0;
            await responseBodyStream.CopyToAsync(originalBodyStream);

            // Store the request metric
            lock (_lock)
            {
                _recentRequests.Add(requestMetric);
                if (_recentRequests.Count > MaxRecentRequests)
                {
                    _recentRequests.RemoveAt(0);
                }
            }

            // Log the request
            _logger.LogInformation("Request {RequestId}: {Method} {Path} -> {StatusCode} in {ResponseTime}ms (Service: {Service})",
                requestMetric.RequestId, requestMetric.Method, requestMetric.Path, 
                requestMetric.StatusCode, requestMetric.ResponseTimeMs, requestMetric.Service ?? "unknown");
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            requestMetric.StatusCode = context.Response.StatusCode;
            requestMetric.ResponseTimeMs = stopwatch.ElapsedMilliseconds;
            
            _logger.LogError(ex, "Request {RequestId} failed: {Method} {Path}", 
                requestMetric.RequestId, requestMetric.Method, requestMetric.Path);
            
            lock (_lock)
            {
                _recentRequests.Add(requestMetric);
                if (_recentRequests.Count > MaxRecentRequests)
                {
                    _recentRequests.RemoveAt(0);
                }
            }

            throw;
        }
        finally
        {
            context.Response.Body = originalBodyStream;
        }
    }

    public static List<RequestMetric> GetRecentRequests()
    {
        lock (_lock)
        {
            return new List<RequestMetric>(_recentRequests);
        }
    }

    public static void ClearRequests()
    {
        lock (_lock)
        {
            _recentRequests.Clear();
        }
    }

    public static Dictionary<string, object> GetMetrics()
    {
        lock (_lock)
        {
            var now = DateTime.UtcNow;
            var last5Minutes = _recentRequests.Where(r => r.Timestamp > now.AddMinutes(-5)).ToList();
            var last1Hour = _recentRequests.Where(r => r.Timestamp > now.AddHours(-1)).ToList();

            return new Dictionary<string, object>
            {
                ["totalRequests"] = _recentRequests.Count,
                ["last5MinutesCount"] = last5Minutes.Count,
                ["lastHourCount"] = last1Hour.Count,
                ["averageResponseTime"] = last5Minutes.Any() ? last5Minutes.Average(r => r.ResponseTimeMs) : 0,
                ["requestsPerMinute"] = last5Minutes.Count / 5.0,
                ["statusCodeDistribution"] = last5Minutes.GroupBy(r => r.StatusCode)
                    .ToDictionary(g => g.Key.ToString(), g => g.Count()),
                ["serviceDistribution"] = last5Minutes.GroupBy(r => r.Service ?? "unknown")
                    .ToDictionary(g => g.Key, g => g.Count()),
                ["slowestRequests"] = last5Minutes.OrderByDescending(r => r.ResponseTimeMs)
                    .Take(10)
                    .Select(r => new { r.Path, r.ResponseTimeMs, r.Timestamp })
                    .ToList()
            };
        }
    }
}