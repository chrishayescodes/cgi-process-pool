#!/usr/bin/env dotnet-script
#load "../cgi.csx"

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

class HelloService : CgiHandler
{
    private static readonly List<Dictionary<string, object>> Messages = new();
    private static int _nextId = 1;

    public override async Task<CgiResponse> HandleAsync(CgiRequest request)
    {
        Console.WriteLine($"[HelloService] Handling {request.Method} {request.Path}");
        
        return (request.Path, request.Method) switch
        {
            ("/", "GET") => HandleRoot(request),
            ("/hello", "GET") => HandleHello(request),
            ("/messages", "GET") => HandleGetMessages(),
            ("/messages", "POST") => HandlePostMessage(request),
            ("/health", "GET") => HandleHealth(),
            ("/echo", _) => HandleEcho(request),
            _ => NotFound($"Path {request.Path} not found")
        };
    }
    
    private CgiResponse HandleRoot(CgiRequest request)
    {
        var html = @"
<!DOCTYPE html>
<html>
<head>
    <title>C# CGI Service</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        .endpoint { margin: 10px 0; padding: 10px; background: #f5f5f5; }
        .method { font-weight: bold; color: #007acc; }
    </style>
</head>
<body>
    <h1>C# CGI Service Example</h1>
    <p>Welcome to the C# CGI abstraction demo!</p>
    
    <h2>Available Endpoints:</h2>
    <div class='endpoint'>
        <span class='method'>GET</span> / - This page
    </div>
    <div class='endpoint'>
        <span class='method'>GET</span> /hello?name=YourName - Personalized greeting
    </div>
    <div class='endpoint'>
        <span class='method'>GET</span> /messages - List all messages
    </div>
    <div class='endpoint'>
        <span class='method'>POST</span> /messages - Create a new message
    </div>
    <div class='endpoint'>
        <span class='method'>GET</span> /health - Health check
    </div>
    <div class='endpoint'>
        <span class='method'>ANY</span> /echo - Echo request details
    </div>
</body>
</html>";
        return Html(html);
    }
    
    private CgiResponse HandleHello(CgiRequest request)
    {
        var name = request.QueryParams.GetValueOrDefault("name", "World");
        var format = request.QueryParams.GetValueOrDefault("format", "json");
        
        if (format == "html")
        {
            var html = $@"
<!DOCTYPE html>
<html>
<head><title>Hello {name}</title></head>
<body>
    <h1>Hello, {name}!</h1>
    <p>Generated at {DateTime.Now:yyyy-MM-dd HH:mm:ss}</p>
    <a href='/'>Back to home</a>
</body>
</html>";
            return Html(html);
        }
        else
        {
            return Json(new 
            { 
                message = $"Hello, {name}!",
                timestamp = DateTime.UtcNow,
                requestHeaders = request.Headers.Count
            });
        }
    }
    
    private CgiResponse HandleGetMessages()
    {
        return Json(new 
        { 
            messages = Messages,
            count = Messages.Count,
            timestamp = DateTime.UtcNow
        });
    }
    
    private CgiResponse HandlePostMessage(CgiRequest request)
    {
        try
        {
            if (string.IsNullOrEmpty(request.Body))
            {
                return BadRequest("Request body is required");
            }
            
            var message = JsonSerializer.Deserialize<Dictionary<string, object>>(request.Body);
            message["id"] = _nextId++;
            message["created"] = DateTime.UtcNow.ToString("o");
            
            Messages.Add(message);
            
            return Created(message, $"/messages/{message["id"]}");
        }
        catch (JsonException ex)
        {
            return BadRequest($"Invalid JSON: {ex.Message}");
        }
    }
    
    private CgiResponse HandleHealth()
    {
        return Json(new 
        { 
            status = "healthy",
            service = "hello-service",
            version = "1.0.0",
            uptime = DateTime.UtcNow.ToString("o"),
            messageCount = Messages.Count
        });
    }
    
    private CgiResponse HandleEcho(CgiRequest request)
    {
        return Json(new 
        {
            method = request.Method,
            path = request.Path,
            queryString = request.QueryString,
            queryParams = request.QueryParams,
            headers = request.Headers,
            contentType = request.ContentType,
            bodyLength = request.Body?.Length ?? 0,
            body = request.Body,
            timestamp = DateTime.UtcNow
        });
    }
}

// Start the service
Console.WriteLine("[HelloService] Starting C# CGI Hello Service");
Console.WriteLine($"[HelloService] Arguments: {string.Join(", ", Args.ToArray())}");

try
{
    await CgiHost.RunAsync(new HelloService(), Args.ToArray());
}
catch (Exception ex)
{
    Console.WriteLine($"[HelloService] Fatal error: {ex}");
    Environment.Exit(1);
}