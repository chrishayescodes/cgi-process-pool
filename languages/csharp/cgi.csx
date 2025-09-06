#load "transports/socket.csx"
#load "transports/stdio.csx"

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

public class CgiRequest
{
    public string Method { get; set; } = "GET";
    public string Path { get; set; } = "/";
    public string QueryString { get; set; } = "";
    public Dictionary<string, string> Headers { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, string> QueryParams { get; set; } = new();
    public string Body { get; set; } = "";
    public string ContentType { get; set; } = "text/plain";
    public string HttpVersion { get; set; } = "HTTP/1.1";
}

public class CgiResponse
{
    public int StatusCode { get; set; } = 200;
    public string StatusText { get; set; } = "OK";
    public Dictionary<string, string> Headers { get; set; } = new();
    public string ContentType { get; set; } = "text/plain";
    public object Body { get; set; } = "";
    public string HttpVersion { get; set; } = "HTTP/1.1";
}

public interface ICgiHandler
{
    Task<CgiResponse> HandleAsync(CgiRequest request);
}

public interface ICgiTransport
{
    Task<CgiRequest> ReadRequestAsync();
    Task WriteResponseAsync(CgiResponse response);
    void Dispose();
}

public abstract class CgiHandler : ICgiHandler
{
    public abstract Task<CgiResponse> HandleAsync(CgiRequest request);

    protected CgiResponse Ok(object body = null)
    {
        return new CgiResponse
        {
            StatusCode = 200,
            StatusText = "OK",
            Body = body ?? ""
        };
    }

    protected CgiResponse Created(object body, string location = null)
    {
        var response = new CgiResponse
        {
            StatusCode = 201,
            StatusText = "Created",
            Body = body ?? ""
        };
        
        if (!string.IsNullOrEmpty(location))
        {
            response.Headers["Location"] = location;
        }
        
        return response;
    }

    protected CgiResponse NoContent()
    {
        return new CgiResponse
        {
            StatusCode = 204,
            StatusText = "No Content",
            Body = ""
        };
    }

    protected CgiResponse BadRequest(string message = null)
    {
        return new CgiResponse
        {
            StatusCode = 400,
            StatusText = "Bad Request",
            Body = message ?? "Bad Request"
        };
    }

    protected CgiResponse Unauthorized()
    {
        return new CgiResponse
        {
            StatusCode = 401,
            StatusText = "Unauthorized",
            Body = "Unauthorized"
        };
    }

    protected CgiResponse Forbidden()
    {
        return new CgiResponse
        {
            StatusCode = 403,
            StatusText = "Forbidden",
            Body = "Forbidden"
        };
    }

    protected CgiResponse NotFound(string message = null)
    {
        return new CgiResponse
        {
            StatusCode = 404,
            StatusText = "Not Found",
            Body = message ?? "Not Found"
        };
    }

    protected CgiResponse NotAllowed()
    {
        return new CgiResponse
        {
            StatusCode = 405,
            StatusText = "Method Not Allowed",
            Body = "Method Not Allowed"
        };
    }

    protected CgiResponse ServerError(string message = null)
    {
        return new CgiResponse
        {
            StatusCode = 500,
            StatusText = "Internal Server Error",
            Body = message ?? "Internal Server Error"
        };
    }

    protected CgiResponse NotImplemented()
    {
        return new CgiResponse
        {
            StatusCode = 501,
            StatusText = "Not Implemented",
            Body = "Not Implemented"
        };
    }

    protected CgiResponse Json(object obj)
    {
        return new CgiResponse
        {
            StatusCode = 200,
            StatusText = "OK",
            ContentType = "application/json",
            Body = obj
        };
    }

    protected CgiResponse Html(string html)
    {
        return new CgiResponse
        {
            StatusCode = 200,
            StatusText = "OK",
            ContentType = "text/html",
            Body = html
        };
    }

    protected CgiResponse Text(string text)
    {
        return new CgiResponse
        {
            StatusCode = 200,
            StatusText = "OK",
            ContentType = "text/plain",
            Body = text
        };
    }

    protected CgiResponse File(byte[] bytes, string mimeType)
    {
        return new CgiResponse
        {
            StatusCode = 200,
            StatusText = "OK",
            ContentType = mimeType,
            Body = bytes
        };
    }
}

public static class CgiHost
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    public static async Task RunAsync(ICgiHandler handler, string[] args)
    {
        ICgiTransport transport = null;
        
        try
        {
            transport = CreateTransport(args);
            
            Console.WriteLine($"[CGI] Starting service with {transport.GetType().Name}");
            
            while (true)
            {
                try
                {
                    var request = await transport.ReadRequestAsync();
                    if (request == null)
                    {
                        break;
                    }
                    
                    Console.WriteLine($"[CGI] {DateTime.Now:HH:mm:ss} {request.Method} {request.Path}");
                    
                    var response = await handler.HandleAsync(request);
                    await transport.WriteResponseAsync(response);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[CGI] Request error: {ex.Message}");
                    
                    try
                    {
                        var errorResponse = new CgiResponse
                        {
                            StatusCode = 500,
                            StatusText = "Internal Server Error",
                            Body = "Internal Server Error"
                        };
                        await transport.WriteResponseAsync(errorResponse);
                    }
                    catch
                    {
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[CGI] Fatal error: {ex.Message}");
            throw;
        }
        finally
        {
            transport?.Dispose();
            Console.WriteLine("[CGI] Service stopped");
        }
    }

    private static ICgiTransport CreateTransport(string[] args)
    {
        var mode = Environment.GetEnvironmentVariable("CGI_MODE")?.ToLower();
        
        if (args.Any(a => a == "--stdio"))
        {
            mode = "stdio";
        }
        else if (args.Any(a => a == "--fastcgi"))
        {
            throw new NotImplementedException("FastCGI transport not yet implemented");
        }
        else if (args.Length > 0 && int.TryParse(args[0], out var port))
        {
            mode = "socket";
        }
        
        switch (mode)
        {
            case "stdio":
                return new StdioTransport();
            
            case "socket":
            default:
                var socketPort = 8080;
                if (args.Length > 0 && int.TryParse(args[0], out var p))
                {
                    socketPort = p;
                }
                return new SocketTransport(socketPort);
        }
    }

    public static string SerializeBody(object body)
    {
        if (body == null)
            return "";
        
        if (body is string str)
            return str;
        
        if (body is byte[] bytes)
            return Convert.ToBase64String(bytes);
        
        return JsonSerializer.Serialize(body, JsonOptions);
    }

    public static Dictionary<string, string> ParseQueryString(string queryString)
    {
        var result = new Dictionary<string, string>();
        
        if (string.IsNullOrEmpty(queryString))
            return result;
        
        if (queryString.StartsWith("?"))
            queryString = queryString.Substring(1);
        
        var pairs = queryString.Split('&');
        foreach (var pair in pairs)
        {
            var parts = pair.Split('=');
            if (parts.Length == 2)
            {
                var key = Uri.UnescapeDataString(parts[0]);
                var value = Uri.UnescapeDataString(parts[1]);
                result[key] = value;
            }
            else if (parts.Length == 1 && !string.IsNullOrEmpty(parts[0]))
            {
                result[Uri.UnescapeDataString(parts[0])] = "";
            }
        }
        
        return result;
    }
}