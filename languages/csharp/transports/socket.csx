using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

public class SocketTransport : ICgiTransport
{
    private readonly TcpListener _listener;
    private TcpClient _client;
    private NetworkStream _stream;
    private StreamReader _reader;
    private StreamWriter _writer;
    private readonly int _port;

    public SocketTransport(int port)
    {
        _port = port;
        _listener = new TcpListener(IPAddress.Any, port);
    }

    public async Task<CgiRequest> ReadRequestAsync()
    {
        try
        {
            if (_client == null || !_client.Connected)
            {
                if (!_listener.Server.IsBound)
                {
                    _listener.Start();
                    Console.WriteLine($"[Socket] Listening on port {_port}");
                }
                
                _client = await _listener.AcceptTcpClientAsync();
                _stream = _client.GetStream();
                _reader = new StreamReader(_stream, Encoding.UTF8);
                _writer = new StreamWriter(_stream, Encoding.UTF8) { AutoFlush = true };
                Console.WriteLine("[Socket] Client connected");
            }

            var request = new CgiRequest();
            
            var requestLine = await _reader.ReadLineAsync();
            if (string.IsNullOrEmpty(requestLine))
            {
                CloseConnection();
                return null;
            }

            var parts = requestLine.Split(' ');
            if (parts.Length < 3)
            {
                throw new InvalidOperationException($"Invalid request line: {requestLine}");
            }

            request.Method = parts[0].ToUpper();
            var fullPath = parts[1];
            request.HttpVersion = parts[2];

            var queryIndex = fullPath.IndexOf('?');
            if (queryIndex >= 0)
            {
                request.Path = fullPath.Substring(0, queryIndex);
                request.QueryString = fullPath.Substring(queryIndex);
                request.QueryParams = CgiHost.ParseQueryString(request.QueryString);
            }
            else
            {
                request.Path = fullPath;
                request.QueryString = "";
                request.QueryParams = new Dictionary<string, string>();
            }

            string line;
            var contentLength = 0;
            while (!string.IsNullOrEmpty(line = await _reader.ReadLineAsync()))
            {
                var colonIndex = line.IndexOf(':');
                if (colonIndex > 0)
                {
                    var key = line.Substring(0, colonIndex).Trim();
                    var value = line.Substring(colonIndex + 1).Trim();
                    request.Headers[key] = value;

                    if (key.Equals("Content-Length", StringComparison.OrdinalIgnoreCase))
                    {
                        int.TryParse(value, out contentLength);
                    }
                    else if (key.Equals("Content-Type", StringComparison.OrdinalIgnoreCase))
                    {
                        request.ContentType = value;
                    }
                }
            }

            if (contentLength > 0)
            {
                var buffer = new char[contentLength];
                var totalRead = 0;
                while (totalRead < contentLength)
                {
                    var read = await _reader.ReadAsync(buffer, totalRead, contentLength - totalRead);
                    if (read == 0)
                        break;
                    totalRead += read;
                }
                request.Body = new string(buffer, 0, totalRead);
            }

            return request;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Socket] Read error: {ex.Message}");
            CloseConnection();
            return null;
        }
    }

    public async Task WriteResponseAsync(CgiResponse response)
    {
        try
        {
            if (_writer == null)
            {
                throw new InvalidOperationException("No client connected");
            }

            await _writer.WriteLineAsync($"{response.HttpVersion} {response.StatusCode} {response.StatusText}");

            var body = CgiHost.SerializeBody(response.Body);
            var bodyBytes = Encoding.UTF8.GetBytes(body);

            if (!response.Headers.ContainsKey("Content-Type"))
            {
                response.Headers["Content-Type"] = response.ContentType;
            }
            
            response.Headers["Content-Length"] = bodyBytes.Length.ToString();
            response.Headers["Connection"] = "close";

            foreach (var header in response.Headers)
            {
                await _writer.WriteLineAsync($"{header.Key}: {header.Value}");
            }

            await _writer.WriteLineAsync();
            
            if (bodyBytes.Length > 0)
            {
                await _writer.WriteAsync(body);
            }
            
            await _writer.FlushAsync();
            
            CloseConnection();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Socket] Write error: {ex.Message}");
            CloseConnection();
        }
    }

    private void CloseConnection()
    {
        try
        {
            _reader?.Dispose();
            _writer?.Dispose();
            _stream?.Dispose();
            _client?.Close();
        }
        catch { }
        finally
        {
            _reader = null;
            _writer = null;
            _stream = null;
            _client = null;
        }
    }

    public void Dispose()
    {
        CloseConnection();
        try
        {
            _listener?.Stop();
        }
        catch { }
    }
}