# C# CGI Abstraction

This is the part I'm most proud of - Claude and I built a pretty clean abstraction for writing CGI services in C# that works with both traditional CGI (stdin/stdout) and modern socket communication. Same code, different transports.

## Why this is cool

The main insight was realizing that CGI is just HTTP over different transports. So I built an abstraction that lets you write the same C# code whether you're:
- Running as a traditional CGI script (stdin/stdout)  
- Running as a TCP service (socket)
- Running as something else entirely (future FastCGI support?)

You just focus on the HTTP logic - method, path, headers, body. The transport layer is somebody else's problem.

Plus, it uses C# scripting (dotnet-script), so no compilation step. Just run the `.csx` file.

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

## How it plugs into the main system

The C# abstraction works seamlessly with the process pool:

- Services are defined in `discovery/manifest.json` and get discovered automatically
- The example service (`hello-service.csx`) runs on port 8005 and gets managed like any other CGI process
- YARP routes `/csharp_abstraction/*` to it
- The dynamic port system handles everything - no hardcoded ports to worry about

Want to test it?
```bash
# Start everything
make start

# Hit the C# service through YARP
curl http://localhost:8080/csharp_abstraction/
curl http://localhost:8080/csharp_abstraction/hello?name=World
curl http://localhost:8080/csharp_abstraction/health
```

The service gets the same monitoring, health checks, and load balancing as everything else.

## Compatibility

- Works with the existing CGI process pool manager
- Compatible with YARP proxy configurations  
- Supports gradual migration from raw socket code
- Integrated with dynamic port allocation system
- Future support planned for FastCGI transport