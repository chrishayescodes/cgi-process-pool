using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

public class StdioTransport : ICgiTransport
{
    private readonly TextReader _input;
    private readonly TextWriter _output;
    private bool _isFirstRequest = true;

    public StdioTransport()
    {
        _input = Console.In;
        _output = Console.Out;
        Console.SetIn(new StreamReader(Stream.Null));
        Console.SetOut(new StreamWriter(Stream.Null) { AutoFlush = true });
        Console.SetError(new StreamWriter(new FileStream("/dev/null", FileMode.Append, FileAccess.Write)) { AutoFlush = true });
    }

    public async Task<CgiRequest> ReadRequestAsync()
    {
        try
        {
            if (!_isFirstRequest)
            {
                return null;
            }
            _isFirstRequest = false;

            var request = new CgiRequest();
            
            request.Method = Environment.GetEnvironmentVariable("REQUEST_METHOD") ?? "GET";
            request.Path = Environment.GetEnvironmentVariable("PATH_INFO") ?? "/";
            request.QueryString = Environment.GetEnvironmentVariable("QUERY_STRING") ?? "";
            request.ContentType = Environment.GetEnvironmentVariable("CONTENT_TYPE") ?? "text/plain";
            
            request.QueryParams = CgiHost.ParseQueryString(request.QueryString);

            var contentLengthStr = Environment.GetEnvironmentVariable("CONTENT_LENGTH");
            if (!string.IsNullOrEmpty(contentLengthStr) && int.TryParse(contentLengthStr, out var contentLength) && contentLength > 0)
            {
                var buffer = new char[contentLength];
                var totalRead = 0;
                while (totalRead < contentLength)
                {
                    var read = await _input.ReadAsync(buffer, totalRead, contentLength - totalRead);
                    if (read == 0)
                        break;
                    totalRead += read;
                }
                request.Body = new string(buffer, 0, totalRead);
            }

            foreach (DictionaryEntry envVar in Environment.GetEnvironmentVariables())
            {
                var key = envVar.Key.ToString();
                if (key.StartsWith("HTTP_"))
                {
                    var headerName = key.Substring(5).Replace('_', '-');
                    request.Headers[headerName] = envVar.Value?.ToString() ?? "";
                }
            }

            var serverProtocol = Environment.GetEnvironmentVariable("SERVER_PROTOCOL");
            if (!string.IsNullOrEmpty(serverProtocol))
            {
                request.HttpVersion = serverProtocol;
            }

            return request;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[Stdio] Read error: {ex.Message}");
            return null;
        }
    }

    public async Task WriteResponseAsync(CgiResponse response)
    {
        try
        {
            await _output.WriteLineAsync($"Status: {response.StatusCode} {response.StatusText}");

            if (!response.Headers.ContainsKey("Content-Type"))
            {
                response.Headers["Content-Type"] = response.ContentType;
            }

            foreach (var header in response.Headers)
            {
                await _output.WriteLineAsync($"{header.Key}: {header.Value}");
            }

            await _output.WriteLineAsync();

            var body = CgiHost.SerializeBody(response.Body);
            if (!string.IsNullOrEmpty(body))
            {
                await _output.WriteAsync(body);
            }
            
            await _output.FlushAsync();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[Stdio] Write error: {ex.Message}");
        }
    }

    public void Dispose()
    {
    }
}