using System.Diagnostics;
using System.Text.Json;

namespace CGIProxy.Services;

public class ProcessInfo
{
    public int Pid { get; set; }
    public string Name { get; set; } = string.Empty;
    public int Port { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public long MemoryUsage { get; set; }
    public double CpuUsage { get; set; }
    public int RequestCount { get; set; }
    public DateTime LastHealthCheck { get; set; }
}

public class PoolInfo
{
    public string Name { get; set; } = string.Empty;
    public List<ProcessInfo> Processes { get; set; } = new List<ProcessInfo>();
    public int MinProcesses { get; set; }
    public int MaxProcesses { get; set; }
    public int ActiveProcesses => Processes.Count(p => p.Status == "Healthy");
}

public class ProcessMonitorService : BackgroundService
{
    private readonly ILogger<ProcessMonitorService> _logger;
    private readonly HttpClient _httpClient;
    private readonly Dictionary<string, PoolInfo> _pools;

    public ProcessMonitorService(ILogger<ProcessMonitorService> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClient = httpClientFactory.CreateClient();
        _pools = new Dictionary<string, PoolInfo>();
    }

    public Dictionary<string, PoolInfo> GetPools() => _pools;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await UpdateProcessInfo();
                await Task.Delay(5000, stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating process info");
            }
        }
    }

    private async Task UpdateProcessInfo()
    {
        var upstreamConfig = await ReadUpstreamConfig();
        var processes = GetCGIProcesses();
        
        UpdatePools(upstreamConfig, processes);
        await PerformHealthChecks();
    }

    private async Task<Dictionary<string, List<int>>> ReadUpstreamConfig()
    {
        var result = new Dictionary<string, List<int>>();
        var configPath = "/tmp/cgi_upstreams.conf";
        
        if (File.Exists(configPath))
        {
            var lines = await File.ReadAllLinesAsync(configPath);
            string? currentPool = null;
            
            foreach (var line in lines)
            {
                if (line.Contains("upstream") && line.Contains("_pool"))
                {
                    currentPool = line.Split(' ')[1].Replace("_pool", "");
                    result[currentPool] = new List<int>();
                }
                else if (currentPool != null && line.Contains("server 127.0.0.1:"))
                {
                    var portStr = line.Split(':')[1].Split(' ')[0];
                    if (int.TryParse(portStr, out int port))
                    {
                        result[currentPool].Add(port);
                    }
                }
            }
        }
        
        return result;
    }

    private List<(int pid, string name, int port)> GetCGIProcesses()
    {
        var processes = new List<(int, string, int)>();
        
        try
        {
            var processInfo = new ProcessStartInfo
            {
                FileName = "/bin/bash",
                Arguments = "-c \"ps aux | grep -E '(search|auth).cgi' | grep -v grep\"",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = Process.Start(processInfo);
            if (process != null)
            {
                using var reader = process.StandardOutput;
                var output = reader.ReadToEnd();
                
                foreach (var line in output.Split('\n', StringSplitOptions.RemoveEmptyEntries))
                {
                    var parts = line.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length >= 11)
                    {
                        if (int.TryParse(parts[1], out int pid))
                        {
                            var cmdLine = string.Join(" ", parts.Skip(10));
                            var name = cmdLine.Contains("search.cgi") ? "search" : "auth";
                            
                            var lastPart = parts.Last();
                            if (int.TryParse(lastPart, out int port))
                            {
                                processes.Add((pid, name, port));
                            }
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting CGI processes");
        }
        
        return processes;
    }

    private void UpdatePools(Dictionary<string, List<int>> upstreamConfig, List<(int pid, string name, int port)> processes)
    {
        foreach (var poolConfig in upstreamConfig)
        {
            if (!_pools.ContainsKey(poolConfig.Key))
            {
                _pools[poolConfig.Key] = new PoolInfo 
                { 
                    Name = poolConfig.Key,
                    MinProcesses = poolConfig.Key == "search" ? 2 : 1,
                    MaxProcesses = poolConfig.Key == "search" ? 5 : 3
                };
            }
            
            var pool = _pools[poolConfig.Key];
            pool.Processes.Clear();
            
            foreach (var port in poolConfig.Value)
            {
                var processData = processes.FirstOrDefault(p => p.port == port);
                
                var processInfo = new ProcessInfo
                {
                    Port = port,
                    Name = poolConfig.Key + ".cgi",
                    Status = processData.pid > 0 ? "Healthy" : "Unknown"
                };
                
                if (processData.pid > 0)
                {
                    processInfo.Pid = processData.pid;
                    processInfo.StartTime = GetProcessStartTime(processData.pid);
                    processInfo.MemoryUsage = GetProcessMemory(processData.pid);
                }
                
                pool.Processes.Add(processInfo);
            }
        }
    }

    private DateTime GetProcessStartTime(int pid)
    {
        try
        {
            var statPath = $"/proc/{pid}/stat";
            if (File.Exists(statPath))
            {
                return DateTime.Now.AddMinutes(-5);
            }
        }
        catch { }
        
        return DateTime.Now;
    }

    private long GetProcessMemory(int pid)
    {
        try
        {
            var statusPath = $"/proc/{pid}/status";
            if (File.Exists(statusPath))
            {
                var lines = File.ReadAllLines(statusPath);
                var vmRssLine = lines.FirstOrDefault(l => l.StartsWith("VmRSS:"));
                if (vmRssLine != null)
                {
                    var parts = vmRssLine.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length >= 2 && long.TryParse(parts[1], out long kb))
                    {
                        return kb * 1024;
                    }
                }
            }
        }
        catch { }
        
        return 0;
    }

    private async Task PerformHealthChecks()
    {
        foreach (var pool in _pools.Values)
        {
            foreach (var process in pool.Processes)
            {
                try
                {
                    var response = await _httpClient.GetAsync($"http://localhost:{process.Port}?q=health");
                    process.Status = response.IsSuccessStatusCode ? "Healthy" : "Unhealthy";
                    process.LastHealthCheck = DateTime.Now;
                    
                    if (response.IsSuccessStatusCode)
                    {
                        process.RequestCount++;
                    }
                }
                catch
                {
                    process.Status = "Unreachable";
                    process.LastHealthCheck = DateTime.Now;
                }
            }
        }
    }
}