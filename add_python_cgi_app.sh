#!/bin/bash

# Script to add a new Python CGI application with full YARP integration
# Usage: ./add_python_cgi_app.sh <app_name> <start_port> [instance_count]

set -e

APP_NAME="$1"
START_PORT="$2"
INSTANCE_COUNT="${3:-2}"

if [ -z "$APP_NAME" ] || [ -z "$START_PORT" ]; then
    echo "Usage: $0 <app_name> <start_port> [instance_count]"
    echo "Example: $0 analytics 8007 3"
    exit 1
fi

echo "🐍 Adding Python CGI application: $APP_NAME"
echo "📡 Start port: $START_PORT"
echo "🔢 Instances: $INSTANCE_COUNT"

# 1. Create Python CGI application source
echo "📝 Creating Python CGI source file..."
cat > "${APP_NAME}.py" << 'EOF'
#!/usr/bin/env python3

"""
APP_NAME_PLACEHOLDER Python CGI HTTP Server
A lightweight HTTP server that demonstrates CGI-style processing in Python.
Can be integrated into the CGI Process Pool system.
"""

import sys
import json
import time
import os
import socket
import threading
import signal
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

class PythonCGIHandler(BaseHTTPRequestHandler):
    """HTTP request handler for Python CGI service"""
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_url = urlparse(self.path)
        query_params = parse_qs(parsed_url.query)
        
        # Extract parameters for health check
        status_param = query_params.get('status', [None])[0]
        service_param = query_params.get('service', ['unknown'])[0]
        data_param = query_params.get('data', [''])[0]
        
        # Handle health check
        if status_param == 'health':
            response_data = {
                'status': 'healthy',
                'service': 'APP_NAME_PLACEHOLDER',
                'language': 'python',
                'pid': os.getpid(),
                'timestamp': int(time.time()),
                'version': '1.0.0'
            }
        else:
            # Prepare response data
            response_data = {
                'service': 'APP_NAME_PLACEHOLDER',
                'language': 'python',
                'query': {
                    'service': service_param,
                    'data': data_param
                },
                'data': {
                    'status': 'success',
                    'message': f'APP_NAME_PLACEHOLDER Python service is running',
                    'processed_data': data_param.upper() if data_param else 'No data provided'
                },
                'pid': os.getpid(),
                'timestamp': int(time.time()),
                'version': '1.0.0',
                'server_info': {
                    'python_version': sys.version.split()[0],
                    'thread_id': threading.get_ident()
                }
            }
        
        # Send response
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        
        response_json = json.dumps(response_data, indent=2)
        self.wfile.write(response_json.encode('utf-8'))
    
    def do_POST(self):
        """Handle POST requests"""
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode('utf-8')
        
        try:
            request_data = json.loads(post_data) if post_data else {}
        except json.JSONDecodeError:
            request_data = {'raw_data': post_data}
        
        response_data = {
            'service': 'APP_NAME_PLACEHOLDER',
            'language': 'python',
            'method': 'POST',
            'received_data': request_data,
            'data': {
                'status': 'success',
                'message': 'POST request processed successfully',
                'processed_items': len(request_data) if isinstance(request_data, dict) else 1
            },
            'pid': os.getpid(),
            'timestamp': int(time.time()),
            'version': '1.0.0'
        }
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        
        response_json = json.dumps(response_data, indent=2)
        self.wfile.write(response_json.encode('utf-8'))
    
    def log_message(self, format, *args):
        """Override to customize logging"""
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] APP_NAME_PLACEHOLDER PID {os.getpid()}: {format % args}")

class PythonCGIServer:
    """Python CGI HTTP Server"""
    
    def __init__(self, port):
        self.port = port
        self.server = None
        self.running = False
    
    def start(self):
        """Start the HTTP server"""
        try:
            self.server = HTTPServer(('0.0.0.0', self.port), PythonCGIHandler)
            self.running = True
            
            print(f"APP_NAME_PLACEHOLDER Python service started on port {self.port} (PID: {os.getpid()})")
            print(f"Python version: {sys.version}")
            print(f"Listening on http://0.0.0.0:{self.port}")
            
            # Start serving requests
            self.server.serve_forever()
            
        except KeyboardInterrupt:
            self.shutdown()
        except Exception as e:
            print(f"Error starting server: {e}")
            sys.exit(1)
    
    def shutdown(self):
        """Shutdown the server"""
        if self.server and self.running:
            print(f"\nAPP_NAME_PLACEHOLDER Python service (PID {os.getpid()}) shutting down...")
            self.server.shutdown()
            self.server.server_close()
            self.running = False

def signal_handler(sig, frame):
    """Handle shutdown signals"""
    print(f"\nReceived signal {sig}, shutting down APP_NAME_PLACEHOLDER Python service...")
    sys.exit(0)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 APP_NAME_PLACEHOLDER.py <port>")
        print("Example: python3 APP_NAME_PLACEHOLDER.py 8007")
        sys.exit(1)
    
    try:
        port = int(sys.argv[1])
    except ValueError:
        print("Error: Port must be a valid integer")
        sys.exit(1)
    
    if port < 1024 or port > 65535:
        print("Error: Port must be between 1024 and 65535")
        sys.exit(1)
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Start the server
    server = PythonCGIServer(port)
    server.start()

if __name__ == "__main__":
    main()
EOF

# Replace placeholder with actual app name
sed -i "s/APP_NAME_PLACEHOLDER/${APP_NAME}/g" "${APP_NAME}.py"

# Make script executable
chmod +x "${APP_NAME}.py"

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
        'command': 'python3 ./${APP_NAME}.py',\\
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
    sed -i "s|cmdLine.Contains(\"python_cgi\") ? \"python_cgi\" :|cmdLine.Contains(\"python_cgi\") ? \"python_cgi\" : cmdLine.Contains(\"${APP_NAME}.py\") ? \"${APP_NAME}\" :|" proxy/CGIProxy/Services/ProcessMonitorService.cs
fi

echo ""
echo "✅ Successfully added ${APP_NAME} Python service!"
echo ""
echo "🚀 To start the system with your new service:"
echo "   1. Terminal 1: make run-pool"
echo "   2. Terminal 2: make run-yarp"
echo ""
echo "🧪 To test the new service:"
echo "   curl \"http://localhost:8080/api/${APP_NAME}?service=hello&data=world\""
echo "   curl \"http://localhost:8080/api/${APP_NAME}?status=health\""
echo ""
echo "📊 Monitor at: http://localhost:8080/admin"
echo ""