# C# Script CGI Communication Abstraction Specification

## Overview
This specification defines a communication abstraction layer for C# script (.csx) CGI services that allows developers to focus on HTTP semantics without dealing with transport mechanisms.

## Core Components

### 1. Request Model
```csharp
public class CgiRequest
{
    public string Method { get; set; }        // GET, POST, PUT, DELETE, etc.
    public string Path { get; set; }          // /api/users
    public string QueryString { get; set; }   // ?id=123&name=test
    public Dictionary<string, string> Headers { get; set; }
    public Dictionary<string, string> QueryParams { get; set; }
    public string Body { get; set; }
    public string ContentType { get; set; }   // application/json, text/html, etc.
}
```

### 2. Response Model
```csharp
public class CgiResponse
{
    public int StatusCode { get; set; } = 200;
    public string StatusText { get; set; } = "OK";
    public Dictionary<string, string> Headers { get; set; } = new();
    public string ContentType { get; set; } = "text/plain";
    public object Body { get; set; }  // String, byte[], or object (auto-serialized to JSON)
}
```

### 3. Handler Interface
```csharp
public interface ICgiHandler
{
    Task<CgiResponse> HandleAsync(CgiRequest request);
}
```

### 4. Transport Abstraction
```csharp
public interface ICgiTransport
{
    Task<CgiRequest> ReadRequestAsync();
    Task WriteResponseAsync(CgiResponse response);
}

// Implementations
public class SocketTransport : ICgiTransport { }  // Current TCP socket mode
public class StdioTransport : ICgiTransport { }   // Classic CGI stdio mode
public class FastCgiTransport : ICgiTransport { } // Future FastCGI support
```

## Usage Patterns

### Simple Service Example
```csharp
#load "cgi.csx"

class MyService : CgiHandler
{
    public override async Task<CgiResponse> HandleAsync(CgiRequest request)
    {
        return request.Method switch
        {
            "GET" => HandleGet(request),
            "POST" => HandlePost(request),
            _ => NotAllowed()
        };
    }
    
    CgiResponse HandleGet(CgiRequest request)
    {
        var name = request.QueryParams.GetValueOrDefault("name", "World");
        return Ok(new { message = $"Hello, {name}!" });
    }
    
    CgiResponse HandlePost(CgiRequest request)
    {
        var data = JsonSerializer.Deserialize<MyData>(request.Body);
        return Created(new { id = Guid.NewGuid(), data });
    }
}

// Start the service
await CgiHost.RunAsync(new MyService(), Args);
```

### Helper Methods (Built into base class)
```csharp
// Success responses
Ok(body)                    // 200 OK
Created(body, location?)    // 201 Created
NoContent()                 // 204 No Content

// Client error responses  
BadRequest(message?)        // 400 Bad Request
Unauthorized()              // 401 Unauthorized
Forbidden()                 // 403 Forbidden
NotFound(message?)          // 404 Not Found
NotAllowed()               // 405 Method Not Allowed

// Server error responses
ServerError(message?)       // 500 Internal Server Error
NotImplemented()           // 501 Not Implemented

// Content negotiation
Json(object)               // Sets application/json
Html(string)               // Sets text/html
Text(string)               // Sets text/plain
File(bytes, mimeType)      // Binary content with MIME type
```

## Transport Selection

### Via Command Line Argument
```bash
dotnet-script service.csx 8080          # Socket mode (default)
dotnet-script service.csx --stdio       # Stdio mode
dotnet-script service.csx --fastcgi     # FastCGI mode
```

### Via Environment Variable
```bash
CGI_MODE=stdio dotnet-script service.csx
CGI_MODE=socket dotnet-script service.csx 8080
```

## Implementation Requirements

### The Framework Provides:
1. Request parsing from any transport
2. Response formatting for any transport
3. Content-Type handling and serialization
4. Query parameter and header parsing
5. Error handling and logging
6. Graceful shutdown handling

### The Developer Provides:
1. Business logic in HandleAsync method
2. Route handling (if needed)
3. Data validation
4. Application-specific error handling

## Benefits

1. **Simplicity**: Focus on HTTP concepts, not networking
2. **Testability**: Easy unit testing without network setup
3. **Portability**: Switch transports without code changes
4. **Learning**: Perfect for understanding HTTP without complexity
5. **Compatibility**: Works with existing pool manager and YARP proxy

## Migration Path

### Current Code (Socket-specific):
```csharp
var listener = new TcpListener(IPAddress.Any, port);
listener.Start();
var tcpClient = await listener.AcceptTcpClientAsync();
// ... parse HTTP manually ...
```

### New Code (Transport-agnostic):
```csharp
class MyService : CgiHandler
{
    public override async Task<CgiResponse> HandleAsync(CgiRequest request)
    {
        return Ok(new { message = "Hello World" });
    }
}
```

## File Structure
```
languages/
├── csharp/
│   ├── cgi.csx                 # Core abstraction implementation
│   ├── transports/
│   │   ├── socket.csx          # Socket transport
│   │   ├── stdio.csx           # Stdio transport
│   │   └── fastcgi.csx         # FastCGI transport
│   └── templates/
│       └── service.csx.template # Service template
```

## Backward Compatibility
- Existing socket-based services continue to work
- New services can use abstraction immediately
- Gradual migration supported
- Pool manager requires no changes for socket mode
- Stdio mode would require pool manager updates