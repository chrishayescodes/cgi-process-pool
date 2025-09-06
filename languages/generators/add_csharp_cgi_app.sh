#!/bin/bash

# Script to add a new C# script CGI application with full YARP integration
# Usage: ./add_csharp_cgi_app.sh <app_name> <start_port> [instance_count]

set -e

APP_NAME="$1"
START_PORT="$2"
INSTANCE_COUNT="${3:-2}"

if [ -z "$APP_NAME" ] || [ -z "$START_PORT" ]; then
    echo "Usage: $0 <app_name> <start_port> [instance_count]"
    echo "Example: $0 orders 8005 2"
    exit 1
fi

echo "🚀 Adding C# script CGI application: $APP_NAME"
echo "📡 Start port: $START_PORT"
echo "🔢 Instances: $INSTANCE_COUNT"

# 1. Create C# script application source
echo "📝 Creating C# script file..."
cat > "${APP_NAME}.csx" << 'EOF'
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
    Console.WriteLine($"Usage: dotnet-script {System.IO.Path.GetFileName(Environment.GetCommandLineArgs()[0])} <port>");
    Environment.Exit(1);
}

var running = true;
TcpListener listener = null;

// Handle shutdown signals
Console.CancelKeyPress += (sender, e) => {
    e.Cancel = true;
    running = false;
    listener?.Stop();
    Console.WriteLine($"\nAPP_NAME_PLACEHOLDER C# script {Environment.ProcessId} shutting down");
};

try
{
    listener = new TcpListener(IPAddress.Any, port);
    listener.Start();
    
    Console.WriteLine($"APP_NAME_PLACEHOLDER C# script {Environment.ProcessId} listening on port {port}");

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

Console.WriteLine($"APP_NAME_PLACEHOLDER C# script {Environment.ProcessId} stopped");

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
            if (queryParams.ContainsKey("status") && queryParams["status"] == "health")
            {
                responseData = new
                {
                    status = "healthy",
                    service = "APP_NAME_PLACEHOLDER",
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
                    service = "APP_NAME_PLACEHOLDER",
                    script_type = "csx",
                    method = method,
                    path = path,
                    queryParams = queryParams,
                    data = new
                    {
                        message = "APP_NAME_PLACEHOLDER C# script service is running",
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
EOF

# Replace placeholder with actual app name
sed -i "s/APP_NAME_PLACEHOLDER/${APP_NAME}/g" "${APP_NAME}.csx"

# Make script executable
chmod +x "${APP_NAME}.csx"

# 2. Update pool_manager.py
echo "🐍 Updating pool_manager.py..."
# Generate port list
PORTS=""
for ((i=0; i<INSTANCE_COUNT; i++)); do
    PORT=$((START_PORT + i))
    if [ $i -eq 0 ]; then
        PORTS="[$PORT"
    else
        PORTS="${PORTS}, $PORT"
    fi
done
PORTS="${PORTS}]"

# Add to pools dictionary (before the closing brace)
sed -i "/^}/i\\
    '${APP_NAME}': {\\
        'command': 'dotnet-script ./${APP_NAME}.csx',\\
        'ports': ${PORTS},\\
        'min_processes': 1,\\
        'max_processes': ${INSTANCE_COUNT},\\
        'health_check': '/?status=health'\\
    }," pool_manager.py

# 3. Update YARP appsettings.json
echo "⚙️ Updating YARP configuration..."

# Create destinations JSON
DESTINATIONS=""
for ((i=0; i<INSTANCE_COUNT; i++)); do
    PORT=$((START_PORT + i))
    DEST_NAME="${APP_NAME}-$((i+1))"
    if [ $i -eq 0 ]; then
        DESTINATIONS="\"$DEST_NAME\": {\"Address\": \"http://127.0.0.1:$PORT/\"}"
    else
        DESTINATIONS="${DESTINATIONS}, \"$DEST_NAME\": {\"Address\": \"http://127.0.0.1:$PORT/\"}"
    fi
done

# Add route (before admin-route)
ROUTE_JSON="\"${APP_NAME}-route\": {
        \"ClusterId\": \"${APP_NAME}-cluster\",
        \"Match\": {
          \"Path\": \"/api/${APP_NAME}/{**catch-all}\"
        },
        \"Transforms\": [
          { \"PathRemovePrefix\": \"/api/${APP_NAME}\" }
        ],
        \"Metadata\": {
          \"Service\": \"${APP_NAME}\"
        }
      },"

# Add cluster (before admin-cluster)
CLUSTER_JSON="\"${APP_NAME}-cluster\": {
        \"LoadBalancingPolicy\": \"RoundRobin\",
        \"HealthCheck\": {
          \"Active\": {
            \"Enabled\": true,
            \"Interval\": \"00:00:10\",
            \"Timeout\": \"00:00:05\",
            \"Policy\": \"ConsecutiveFailures\",
            \"Path\": \"/?status=health\"
          }
        },
        \"Destinations\": {
          ${DESTINATIONS}
        }
      },"

# Insert route
sed -i "/\"admin-route\":/i\\${ROUTE_JSON}" proxy/CGIProxy/appsettings.json

# Insert cluster  
sed -i "/\"admin-cluster\":/i\\${CLUSTER_JSON}" proxy/CGIProxy/appsettings.json

# 4. Update YARP Program.cs endpoints
echo "🔌 Updating YARP endpoints..."
if ! grep -q "/api/${APP_NAME}" proxy/CGIProxy/Program.cs; then
    sed -i "s|/api/auth\" }|/api/auth\", \"/api/${APP_NAME}\" }|" proxy/CGIProxy/Program.cs
fi

# 5. Update RequestLoggingMiddleware.cs
echo "📊 Updating request logging middleware..."
# Add service detection
NEW_SERVICE_CHECK="else if (context.Request.Path.StartsWithSegments(\"/api/${APP_NAME}\"))
            {
                requestMetric.Service = \"${APP_NAME}\";
            }"

if ! grep -q "/api/${APP_NAME}" proxy/CGIProxy/Middleware/RequestLoggingMiddleware.cs; then
    sed -i "/else if (context.Request.Path.StartsWithSegments(\"/admin\"))/i\\            ${NEW_SERVICE_CHECK}" proxy/CGIProxy/Middleware/RequestLoggingMiddleware.cs
fi

# 6. Update ProcessMonitorService.cs  
echo "🔍 Updating process monitoring..."
# Update regex pattern - check if not already included
if ! grep -q "${APP_NAME}" proxy/CGIProxy/Services/ProcessMonitorService.cs; then
    # Update regex pattern
    sed -i "s|(search\\\\|auth\\\\|python_cgi)|(search\\\\|auth\\\\|python_cgi\\\\|${APP_NAME})|" proxy/CGIProxy/Services/ProcessMonitorService.cs

    # Update name detection
    sed -i "s|cmdLine.Contains(\"python_cgi\") ? \"python_cgi\" :|cmdLine.Contains(\"python_cgi\") ? \"python_cgi\" : cmdLine.Contains(\"${APP_NAME}.csx\") ? \"${APP_NAME}\" :|" proxy/CGIProxy/Services/ProcessMonitorService.cs
fi

echo ""
echo "✅ Successfully added ${APP_NAME} C# script service!"
echo ""
echo "📋 Requirements:"
echo "   - dotnet-script must be installed: dotnet tool install -g dotnet-script"
echo "   - .NET 8 SDK must be available"
echo ""
echo "🚀 To start the system with your new service:"
echo "   1. Terminal 1: make run-pool"
echo "   2. Terminal 2: make run-yarp"
echo ""
echo "🧪 To test the new service:"
echo "   curl \"http://localhost:8080/api/${APP_NAME}?test=hello\""
echo "   curl \"http://localhost:8080/api/${APP_NAME}?status=health\""
echo ""
echo "📊 Monitor at: http://localhost:8080/admin"
echo ""