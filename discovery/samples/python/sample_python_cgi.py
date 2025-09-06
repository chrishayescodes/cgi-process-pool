#!/usr/bin/env python3

"""
Sample Python CGI HTTP Server
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
        
        # Extract parameters
        service_param = query_params.get('service', ['unknown'])[0]
        data_param = query_params.get('data', [''])[0]
        
        # Prepare response data
        response_data = {
            'service': 'python_cgi',
            'query': {
                'service': service_param,
                'data': data_param
            },
            'data': {
                'status': 'success',
                'message': f'Python CGI service processed: {service_param}',
                'processed_data': data_param.upper() if data_param else 'No data provided'
            },
            'pid': os.getpid(),
            'timestamp': int(time.time()),
            'version': '1.0.0',
            'language': 'python',
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
            'service': 'python_cgi',
            'method': 'POST',
            'received_data': request_data,
            'data': {
                'status': 'success',
                'message': 'POST request processed successfully',
                'processed_items': len(request_data) if isinstance(request_data, dict) else 1
            },
            'pid': os.getpid(),
            'timestamp': int(time.time()),
            'version': '1.0.0',
            'language': 'python'
        }
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        
        response_json = json.dumps(response_data, indent=2)
        self.wfile.write(response_json.encode('utf-8'))
    
    def log_message(self, format, *args):
        """Override to customize logging"""
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Python CGI PID {os.getpid()}: {format % args}")

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
            
            print(f"Python CGI service started on port {self.port} (PID: {os.getpid()})")
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
            print(f"\nPython CGI service (PID {os.getpid()}) shutting down...")
            self.server.shutdown()
            self.server.server_close()
            self.running = False

def signal_handler(sig, frame):
    """Handle shutdown signals"""
    print(f"\nReceived signal {sig}, shutting down Python CGI service...")
    sys.exit(0)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 sample_python_cgi.py <port>")
        print("Example: python3 sample_python_cgi.py 8003")
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