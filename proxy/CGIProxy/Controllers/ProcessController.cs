using Microsoft.AspNetCore.Mvc;
using CGIProxy.Services;

namespace CGIProxy.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProcessController : ControllerBase
{
    private readonly ProcessMonitorService _processMonitor;
    private readonly ILogger<ProcessController> _logger;

    public ProcessController(ProcessMonitorService processMonitor, ILogger<ProcessController> logger)
    {
        _processMonitor = processMonitor;
        _logger = logger;
    }

    [HttpGet]
    public IActionResult GetPools()
    {
        var pools = _processMonitor.GetPools();
        return Ok(pools);
    }

    [HttpGet("summary")]
    public IActionResult GetSummary()
    {
        var pools = _processMonitor.GetPools();
        
        var summary = new
        {
            totalPools = pools.Count,
            totalProcesses = pools.Values.Sum(p => p.Processes.Count),
            healthyProcesses = pools.Values.Sum(p => p.ActiveProcesses),
            unhealthyProcesses = pools.Values.Sum(p => p.Processes.Count - p.ActiveProcesses),
            pools = pools.Values.Select(pool => new 
            {
                name = pool.Name,
                processes = pool.Processes.Count,
                healthy = pool.ActiveProcesses,
                minProcesses = pool.MinProcesses,
                maxProcesses = pool.MaxProcesses,
                status = pool.ActiveProcesses >= pool.MinProcesses ? "Healthy" : "Degraded"
            })
        };

        return Ok(summary);
    }

    [HttpGet("{poolName}")]
    public IActionResult GetPool(string poolName)
    {
        var pools = _processMonitor.GetPools();
        
        if (!pools.ContainsKey(poolName))
        {
            return NotFound($"Pool '{poolName}' not found");
        }

        return Ok(pools[poolName]);
    }
}