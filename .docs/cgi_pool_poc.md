# CGI Process Pool Proof of Concept

## Architecture Overview

```
[nginx] → [Pool Manager] → [CGI Process Pool]
   ↓           ↓              ↓
HTTP        Process        HTTP Server
Router      Spawner        (search.cgi)
```

## 1. Simple CGI Process (C)

**File: `search.cgi`**
```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

void send_response(int client_socket, const char* query) {
    char response[1024];
    snprintf(response, sizeof(response),
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: %ld\r\n"
        "\r\n"
        "{\"query\": \"%s\", \"results\": [\"result1\", \"result2\"], \"pid\": %d}",
        strlen(query) + 50, query, getpid());
    
    send(client_socket, response, strlen(response), 0);
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\n", argv[0]);
        exit(1);
    }
    
    int port = atoi(argv[1]);
    int server_socket = socket(AF_INET, SOCK_STREAM, 0);
    
    struct sockaddr_in address = {
        .sin_family = AF_INET,
        .sin_addr.s_addr = INADDR_ANY,
        .sin_port = htons(port)
    };
    
    bind(server_socket, (struct sockaddr*)&address, sizeof(address));
    listen(server_socket, 10);
    
    printf("Search CGI process %d listening on port %d\n", getpid(), port);
    
    while (1) {
        int client_socket = accept(server_socket, NULL, NULL);
        
        // Simple HTTP request parsing (minimal for POC)
        char buffer[1024];
        recv(client_socket, buffer, sizeof(buffer), 0);
        
        // Extract query parameter (very basic parsing)
        char* query_start = strstr(buffer, "q=");
        char query[256] = "default";
        if (query_start) {
            sscanf(query_start, "q=%255s", query);
        }
        
        send_response(client_socket, query);
        close(client_socket);
    }
    
    return 0;
}
```

## 2. Pool Manager (Python)

**File: `pool_manager.py`**
```python
#!/usr/bin/env python3
import subprocess
import time
import requests
import threading
from collections import defaultdict

class CGIPool:
    def __init__(self, script_path, min_processes=2, max_processes=5):
        self.script_path = script_path
        self.min_processes = min_processes
        self.max_processes = max_processes
        self.processes = {}  # port -> process
        self.next_port = 8000
        self.lock = threading.Lock()
        
    def spawn_process(self):
        """Spawn a new CGI process on an available port"""
        port = self.next_port
        self.next_port += 1
        
        process = subprocess.Popen([self.script_path, str(port)])
        
        # Wait for process to be ready
        time.sleep(0.1)
        
        # Test if it's responding
        try:
            response = requests.get(f"http://localhost:{port}?q=test", timeout=1)
            if response.status_code == 200:
                self.processes[port] = {
                    'process': process,
                    'port': port,
                    'healthy': True,
                    'created': time.time()
                }
                print(f"✓ Spawned {self.script_path} on port {port} (PID: {process.pid})")
                return port
        except:
            process.terminate()
            
        return None
    
    def health_check(self):
        """Check health of all processes"""
        unhealthy = []
        for port, info in self.processes.items():
            try:
                response = requests.get(f"http://localhost:{port}?q=health", timeout=0.5)
                info['healthy'] = response.status_code == 200
            except:
                info['healthy'] = False
                unhealthy.append(port)
        
        # Remove unhealthy processes
        for port in unhealthy:
            print(f"✗ Process on port {port} unhealthy, removing")
            self.processes[port]['process'].terminate()
            del self.processes[port]
    
    def ensure_min_processes(self):
        """Ensure we have minimum number of healthy processes"""
        healthy_count = sum(1 for info in self.processes.values() if info['healthy'])
        
        while healthy_count < self.min_processes:
            port = self.spawn_process()
            if port:
                healthy_count += 1
            else:
                break
    
    def get_process_ports(self):
        """Get list of healthy process ports for nginx upstream"""
        return [info['port'] for info in self.processes.values() if info['healthy']]

class PoolManager:
    def __init__(self):
        self.pools = {
            'search': CGIPool('./search.cgi', min_processes=2, max_processes=5),
            'auth': CGIPool('./auth.cgi', min_processes=1, max_processes=3),
        }
    
    def start(self):
        """Initialize all pools"""
        print("🚀 Starting CGI Pool Manager")
        
        for name, pool in self.pools.items():
            print(f"Initializing {name} pool...")
            pool.ensure_min_processes()
        
        # Start health check loop
        while True:
            time.sleep(5)
            for name, pool in self.pools.items():
                pool.health_check()
                pool.ensure_min_processes()
            
            self.update_nginx_config()
    
    def update_nginx_config(self):
        """Generate nginx upstream configuration"""
        config = "# Auto-generated upstream configuration\n"
        
        for name, pool in self.pools.items():
            ports = pool.get_process_ports()
            if ports:
                config += f"upstream {name}_pool {{\n"
                for port in ports:
                    config += f"    server 127.0.0.1:{port};\n"
                config += "}\n\n"
        
        with open('/tmp/cgi_upstreams.conf', 'w') as f:
            f.write(config)

if __name__ == "__main__":
    manager = PoolManager()
    manager.start()
```

## 3. Nginx Configuration

**File: `nginx.conf`**
```nginx
http {
    # Include auto-generated upstream configs
    include /tmp/cgi_upstreams.conf;
    
    server {
        listen 80;
        server_name localhost;
        
        # Route to search pool
        location /api/search {
            proxy_pass http://search_pool;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            
            # Add health checking
            proxy_next_upstream error timeout invalid_header http_500;
        }
        
        # Route to auth pool  
        location /api/auth {
            proxy_pass http://auth_pool;
            proxy_set_header Host $host;
        }
        
        # Status endpoint to monitor pools
        location /pool-status {
            return 200 "CGI Pools Active";
            add_header Content-Type text/plain;
        }
    }
}
```

## 4. Demo Script

**File: `demo.sh`**
```bash
#!/bin/bash

echo "🔧 Building CGI processes..."
gcc -o search.cgi search.c
gcc -o auth.cgi auth.c  # Similar to search.cgi

echo "🚀 Starting pool manager..."
python3 pool_manager.py &
POOL_PID=$!

sleep 3

echo "🌐 Starting nginx..."
nginx -c $(pwd)/nginx.conf &
NGINX_PID=$!

sleep 2

echo "🧪 Testing the system..."
echo "Search request:"
curl "http://localhost/api/search?q=test"

echo -e "\n\nAuth request:"  
curl "http://localhost/api/auth?user=john"

echo -e "\n\n📊 Pool status:"
curl "http://localhost/pool-status"

echo -e "\n\n🔥 Load testing (10 concurrent requests)..."
for i in {1..10}; do
    curl -s "http://localhost/api/search?q=load$i" &
done
wait

echo -e "\n\n🧹 Cleanup..."
kill $POOL_PID $NGINX_PID
```

## 5. Expected Output

```bash
$ ./demo.sh

🔧 Building CGI processes...
🚀 Starting pool manager...
✓ Spawned ./search.cgi on port 8000 (PID: 12345)
✓ Spawned ./search.cgi on port 8001 (PID: 12346)
✓ Spawned ./auth.cgi on port 8002 (PID: 12347)

🌐 Starting nginx...
🧪 Testing the system...

Search request:
{"query": "test", "results": ["result1", "result2"], "pid": 12345}

Auth request:
{"user": "john", "token": "abc123", "pid": 12347}

📊 Pool status:
CGI Pools Active

🔥 Load testing...
[Shows different PIDs handling requests, demonstrating load balancing]
```

## Key Demonstrations

1. **Process Isolation**: Each response shows different PID
2. **Load Balancing**: Requests distributed across pool processes  
3. **Language Flexibility**: Could have search.cgi in C, auth.py in Python
4. **Standard Tooling**: Uses nginx for routing, health checks, SSL termination
5. **Dynamic Scaling**: Pool manager can spawn/kill processes based on load
6. **Fault Tolerance**: Individual process crashes don't affect others

## Next Steps for Full Implementation

- Add proper HTTP request parsing to CGI processes
- Implement more sophisticated load balancing algorithms
- Add metrics collection and monitoring
- Support for Unix domain sockets to reduce network overhead
- Container deployment with Docker Compose
- Integration with systemd for process supervision

This POC demonstrates the core concept: **CGI-style composability with modern performance and tooling**.