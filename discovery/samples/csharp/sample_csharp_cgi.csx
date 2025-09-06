#!/usr/bin/env dotnet-script

#r "nuget: System.Text.Json, 8.0.0"

using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

// Parse command line arguments
if (Args.Count != 1 || !int.TryParse(Args[0], out int port))
{
    Console.WriteLine("Usage: dotnet-script sample_csharp_cgi.csx <port>");
    Environment.Exit(1);
}

var running = true;
TcpListener listener = null;

// Handle shutdown signals
Console.CancelKeyPress += (sender, e) => {
    e.Cancel = true;
    running = false;
    listener?.Stop();
    Console.WriteLine($"\nC# CGI script {Environment.ProcessId} shutting down");
};

try
{
    listener = new TcpListener(IPAddress.Any, port);
    listener.Start();
    
    Console.WriteLine($"C# CGI script {Environment.ProcessId} listening on port {port}");

    while (running)
    {
        try
        {
            var tcpClient = await listener.AcceptTcpClientAsync();
            _ = Task.Run(() => HandleClientAsync(tcpClient));
        }
        catch (ObjectDisposedException)
        {
            // Expected when stopping
            break;
        }
        catch (Exception ex)
        {
            if (running)
                Console.WriteLine($"Accept error: {ex.Message}");
        }
    }
}
catch (Exception ex)
{
    Console.WriteLine($"Server error: {ex.Message}");
}

Console.WriteLine($"C# CGI script {Environment.ProcessId} stopped");

async Task HandleClientAsync(TcpClient client)
{
    try
    {
        using (client)
        using (var stream = client.GetStream())
        using (var reader = new StreamReader(stream))
        {
            var requestLine = await reader.ReadLineAsync();
            if (string.IsNullOrEmpty(requestLine)) return;

            // Read headers until empty line
            string line;
            while (!string.IsNullOrEmpty(line = await reader.ReadLineAsync()))
            {
                // Skip headers for this simple implementation
            }

            // Parse request
            var parts = requestLine.Split(' ');
            if (parts.Length < 2) return;

            var method = parts[0];
            var path = parts[1];
            
            // Extract query parameters
            var queryParams = ParseQueryString(path);
            
            // Handle different request types
            object responseData;
            if (queryParams.ContainsKey("service") && queryParams["service"] == "health")
            {
                responseData = new
                {
                    status = "healthy",
                    service = "csharp-script",
                    script_type = "csx",
                    pid = Environment.ProcessId,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
                    version = "1.0.0"
                };
            }
            else
            {
                responseData = new
                {
                    service = "csharp-script",
                    script_type = "csx",
                    method = method,
                    path = path,
                    queryParams = queryParams,
                    data = new
                    {
                        message = "C# script CGI service is running",
                        framework = ".NET " + Environment.Version.ToString(),
                        script_runner = "dotnet-script",
                        status = "success"
                    },
                    pid = Environment.ProcessId,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
                    version = "1.0.0"
                };
            }

            var json = JsonSerializer.Serialize(responseData, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                WriteIndented = false
            });

            var response = $"HTTP/1.1 200 OK\r\n" +
                          $"Content-Type: application/json\r\n" +
                          $"Content-Length: {Encoding.UTF8.GetByteCount(json)}\r\n" +
                          $"Access-Control-Allow-Origin: *\r\n" +
                          $"Cache-Control: no-cache\r\n" +
                          $"Connection: close\r\n" +
                          $"\r\n" +
                          $"{json}";

            var responseBytes = Encoding.UTF8.GetBytes(response);
            await stream.WriteAsync(responseBytes, 0, responseBytes.Length);
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error handling client: {ex.Message}");
    }
}

Dictionary<string, string> ParseQueryString(string path)
{
    var queryParams = new Dictionary<string, string>();
    
    var queryIndex = path.IndexOf('?');
    if (queryIndex == -1) return queryParams;

    var queryString = path.Substring(queryIndex + 1);
    var pairs = queryString.Split('&');

    foreach (var pair in pairs)
    {
        var keyValue = pair.Split('=', 2);
        if (keyValue.Length == 2)
        {
            var key = Uri.UnescapeDataString(keyValue[0]);
            var value = Uri.UnescapeDataString(keyValue[1]);
            queryParams[key] = value;
        }
    }

    return queryParams;
}