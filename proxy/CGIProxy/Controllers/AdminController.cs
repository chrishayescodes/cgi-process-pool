using Microsoft.AspNetCore.Mvc;
using CGIProxy.Services;
using CGIProxy.Middleware;

namespace CGIProxy.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly ProcessMonitorService _processMonitor;
    private readonly ILogger<AdminController> _logger;

    public AdminController(ProcessMonitorService processMonitor, ILogger<AdminController> logger)
    {
        _processMonitor = processMonitor;
        _logger = logger;
    }

    [HttpGet("dashboard")]
    public IActionResult GetDashboard()
    {
        var pools = _processMonitor.GetPools();
        var metrics = RequestLoggingMiddleware.GetMetrics();
        
        var totalProcesses = pools.Values.Sum(p => p.Processes.Count);
        var healthyProcesses = pools.Values.Sum(p => p.ActiveProcesses);
        var unhealthyProcesses = totalProcesses - healthyProcesses;
        
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

        foreach (var pool in pools.Values)
        {
            var poolStatus = pool.ActiveProcesses >= pool.MinProcesses ? "healthy" : "degraded";
            var poolStatusText = poolStatus == "healthy" ? "Healthy" : "Degraded";
            
            html += $@"
                <div class=""pool-card"">
                    <div class=""pool-header"">
                        <div class=""pool-name"">{pool.Name.ToUpper()} Pool</div>
                        <div class=""pool-status {poolStatus}"">{poolStatusText}</div>
                    </div>
                    <div style=""margin-bottom: 15px; color: #666; font-size: 14px;"">
                        {pool.ActiveProcesses}/{pool.Processes.Count} processes healthy • Min: {pool.MinProcesses} • Max: {pool.MaxProcesses}
                    </div>
                    <ul class=""process-list"">";

            foreach (var process in pool.Processes)
            {
                var statusClass = process.Status.ToLower() switch
                {
                    "healthy" => "healthy",
                    "unhealthy" => "unhealthy",
                    _ => "unknown"
                };
                
                var memoryMB = process.MemoryUsage / (1024 * 1024);
                var uptime = DateTime.Now - process.StartTime;
                
                html += $@"
                        <li class=""process-item"">
                            <div class=""process-info"">
                                <div class=""process-name"">{process.Name} (PID: {process.Pid})</div>
                                <div class=""process-details"">
                                    Port: {process.Port} • Memory: {memoryMB:F1}MB • Uptime: {uptime:hh\:mm\:ss}
                                </div>
                            </div>
                            <div class=""process-status {statusClass}"">{process.Status}</div>
                        </li>";
            }

            html += $@"
                    </ul>
                </div>";
        }

        html += "</div>";

        return Content(html, "text/html");
    }
}