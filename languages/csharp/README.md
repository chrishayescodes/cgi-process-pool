# C# CGI Abstraction

A clean abstraction layer for building CGI services in C# scripts (.csx) that supports multiple transport modes.

## Features

- **Transport Agnostic**: Support for socket (TCP) and stdio (classic CGI) transports
- **Simple API**: Focus on HTTP semantics without dealing with networking
- **Built-in Helpers**: Convenient response methods (Ok, NotFound, Json, Html, etc.)
- **Testable**: Easy unit testing without network setup
- **Lightweight**: Uses C# scripting with dotnet-script

## Quick Start

### Prerequisites

Install dotnet-script:
```bash
dotnet tool install -g dotnet-script
```

### Basic Example

```csharp
#!/usr/bin/env dotnet-script
#load "cgi.csx"

class MyService : CgiHandler
{
    public override async Task<CgiResponse> HandleAsync(CgiRequest request)
    {
        return request.Method switch
        {
            "GET" => Ok(new { message = "Hello World!" }),
            "POST" => Created(new { id = Guid.NewGuid() }),
            _ => NotAllowed()
        };
    }
}

await CgiHost.RunAsync(new MyService(), Args.ToArray());
```

### Running the Service

```bash
# Socket mode (default) - listens on TCP port
dotnet-script service.csx 8080

# Stdio mode - classic CGI via stdin/stdout
dotnet-script service.csx --stdio

# Using environment variable
CGI_MODE=stdio dotnet-script service.csx
```

## API Reference

### Request Model
- `Method`: HTTP method (GET, POST, etc.)
- `Path`: Request path (/api/users)
- `QueryString`: Raw query string (?id=123)
- `QueryParams`: Parsed query parameters
- `Headers`: Request headers
- `Body`: Request body as string
- `ContentType`: Content-Type header value

### Response Model
- `StatusCode`: HTTP status code
- `StatusText`: HTTP status text
- `Headers`: Response headers
- `ContentType`: Content-Type header
- `Body`: Response body (string, byte[], or object)

### Helper Methods
- `Ok(body)` - 200 OK
- `Created(body, location?)` - 201 Created
- `NoContent()` - 204 No Content
- `BadRequest(message?)` - 400 Bad Request
- `NotFound(message?)` - 404 Not Found
- `Json(object)` - JSON response
- `Html(string)` - HTML response
- `Text(string)` - Plain text response

## Examples

See the `examples/` directory for complete examples:
- `hello-service.csx` - Full-featured demo service

## Testing

Run the example service:
```bash
dotnet-script examples/hello-service.csx 9090
```

Test with curl:
```bash
curl http://localhost:9090/
curl http://localhost:9090/hello?name=World
curl -X POST http://localhost:9090/messages -d '{"text":"Hello"}'
```

## Architecture

```
cgi.csx                    # Core abstraction
├── transports/
│   ├── socket.csx        # TCP socket transport
│   └── stdio.csx         # Classic CGI stdio transport
├── templates/
│   └── service.csx.template  # Service template
└── examples/
    └── hello-service.csx     # Example service
```

## Compatibility

- Works with the existing CGI process pool manager
- Compatible with YARP proxy configurations
- Supports gradual migration from raw socket code
- Future support planned for FastCGI transport