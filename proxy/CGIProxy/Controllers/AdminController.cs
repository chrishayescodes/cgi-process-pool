using Microsoft.AspNetCore.Mvc;
using CGIProxy.Middleware;

namespace CGIProxy.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly ILogger<AdminController> _logger;

    public AdminController(ILogger<AdminController> logger)
    {
        _logger = logger;
    }

    [HttpGet("health")]
    public IActionResult GetHealth()
    {
        try
        {
            var metrics = RequestLoggingMiddleware.GetMetrics();
            
            var successCount = 0;
            var totalRequests = Convert.ToInt32(metrics["totalRequests"]);
            
            var statusCodes = metrics["statusCodeDistribution"] as Dictionary<string, object>;
            if (statusCodes?.ContainsKey("200") == true)
            {
                successCount = Convert.ToInt32(statusCodes["200"]);
            }
            
            var successRate = totalRequests > 0 ? (double)successCount / totalRequests * 100 : 100;
            
            return Ok(new
            {
                status = "healthy",
                service = "CGI Proxy Admin API",
                version = "1.1.0",
                timestamp = DateTime.UtcNow,
                metrics = new
                {
                    totalRequests,
                    averageResponseTime = metrics["averageResponseTime"],
                    requestsPerMinute = metrics["requestsPerMinute"],
                    successRate = $"{successRate:F1}%"
                },
                note = "Process monitoring requires ProcessMonitorService integration"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting health status");
            return Ok(new
            {
                status = "healthy",
                service = "CGI Proxy Admin API",
                version = "1.1.0",
                timestamp = DateTime.UtcNow,
                note = "Basic health check - metrics unavailable"
            });
        }
    }

    [HttpGet("dashboard")]
    public IActionResult GetDashboard()
    {
        var metrics = RequestLoggingMiddleware.GetMetrics();
        
        // Simplified dashboard without ProcessMonitorService
        var totalProcesses = 0;
        var healthyProcesses = 0;
        var unhealthyProcesses = 0;
        
        var html = $@"
            <div class=""metrics-grid"">
                <div class=""metric-card"">
                    <h3>📊 Proxy Metrics</h3>
                    <div class=""metric-number blue"">{metrics["totalRequests"]}</div>
                    <div class=""metric-subtitle"">Total Requests</div>
                    <div style=""margin-top: 10px;"">
                        <small>Avg Response: {metrics["averageResponseTime"]:F1}ms</small><br>
                        <small>Requests/min: {metrics["requestsPerMinute"]:F1}</small>
                    </div>
                </div>
                
                <div class=""metric-card"">
                    <h3>⚙️ Process Health</h3>
                    <div class=""metric-number green"">{healthyProcesses}</div>
                    <div class=""metric-subtitle"">Healthy Processes</div>
                    {(unhealthyProcesses > 0 ? $"<div style=\"color: #f44336; margin-top: 5px;\">⚠️ {unhealthyProcesses} Unhealthy</div>" : "")}
                </div>
                
                <div class=""metric-card"">
                    <h3>📈 Success Rate</h3>";

        var statusCodes = metrics["statusCodeDistribution"] as Dictionary<string, object>;
        var successCount = statusCodes?.ContainsKey("200") == true ? Convert.ToInt32(statusCodes["200"]) : 0;
        var totalRequests = Convert.ToInt32(metrics["totalRequests"]);
        var successRate = totalRequests > 0 ? (double)successCount / totalRequests * 100 : 100;
        
        html += $@"
                    <div class=""metric-number {(successRate >= 95 ? "green" : "red")}"">{successRate:F1}%</div>
                    <div class=""metric-subtitle"">Request Success Rate</div>
                </div>
            </div>

            <div class=""processes-grid"">";

        // Static service information (without ProcessMonitorService)
        html += $@"
            <div class=""pool-card"">
                <div class=""pool-header"">
                    <div class=""pool-name"">CGI Services</div>
                    <div class=""pool-status healthy"">Available via Proxy</div>
                </div>
                <div style=""margin-bottom: 15px; color: #666; font-size: 14px;"">
                    Process monitoring requires ProcessMonitorService integration
                </div>
                <ul class=""process-list"">
                    <li class=""process-item"">
                        <div class=""process-info"">
                            <div class=""process-name"">Search Service (ports 8000, 8001)</div>
                            <div class=""process-details"">Available at /api/search</div>
                        </div>
                        <div class=""process-status healthy"">Proxied</div>
                    </li>
                    <li class=""process-item"">
                        <div class=""process-info"">
                            <div class=""process-name"">Auth Service (port 8002)</div>
                            <div class=""process-details"">Available at /api/auth</div>
                        </div>
                        <div class=""process-status healthy"">Proxied</div>
                    </li>
                    <li class=""process-item"">
                        <div class=""process-info"">
                            <div class=""process-name"">Python CGI Service (port 8003)</div>
                            <div class=""process-details"">Available at /api/python</div>
                        </div>
                        <div class=""process-status healthy"">Proxied</div>
                    </li>
                    <li class=""process-item"">
                        <div class=""process-info"">
                            <div class=""process-name"">C# Script Service (port 8004)</div>
                            <div class=""process-details"">Available at /api/csharp</div>
                        </div>
                        <div class=""process-status healthy"">Proxied</div>
                    </li>
                    <li class=""process-item"">
                        <div class=""process-info"">
                            <div class=""process-name"">C# Abstraction Service (port 8005)</div>
                            <div class=""process-details"">Available at /csharp_abstraction</div>
                        </div>
                        <div class=""process-status healthy"">Proxied</div>
                    </li>
                </ul>
            </div>";

        html += "</div>";

        return Content(html, "text/html");
    }
}