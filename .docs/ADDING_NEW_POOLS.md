# Adding New Pools to YARP Configuration

This guide explains how to add new service pools to the CGI Process Pool system.

## Overview

To add a new service pool, you need to:
1. Create the CGI service implementation
2. Update YARP configuration 
3. Update the pool manager
4. Update the process monitoring
5. Test the new service

## Step 1: Create CGI Service Implementation

### 1.1 Create the CGI Service (e.g., `users.c`)

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <pthread.h>
#include <time.h>

void handle_request(int client_socket) {
    char buffer[1024];
    recv(client_socket, buffer, sizeof(buffer), 0);
    
    // Extract query parameters (simplified)
    char *query = strstr(buffer, "GET /?");
    char *user_param = NULL;
    
    if (query) {
        user_param = strstr(query, "user=");
        if (user_param) {
            user_param += 5; // Skip "user="
        }
    }
    
    // Generate response
    char response[2048];
    time_t now = time(NULL);
    
    snprintf(response, sizeof(response),
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: application/json\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "\r\n"
        "{"
        "\"user\": \"%s\", "
        "\"profile\": {\"name\": \"John Doe\", \"email\": \"john@example.com\"}, "
        "\"pid\": %d, "
        "\"timestamp\": %ld"
        "}",
        user_param ? user_param : "unknown",
        getpid(),
        now
    );
    
    send(client_socket, response, strlen(response), 0);
    close(client_socket);
}

void* client_handler(void* arg) {
    int client_socket = *(int*)arg;
    free(arg);
    handle_request(client_socket);
    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\n", argv[0]);
        exit(1);
    }
    
    int port = atoi(argv[1]);
    int server_socket = socket(AF_INET, SOCK_STREAM, 0);
    
    struct sockaddr_in server_addr = {0};
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(port);
    
    bind(server_socket, (struct sockaddr*)&server_addr, sizeof(server_addr));
    listen(server_socket, 5);
    
    printf("Users service listening on port %d (PID: %d)\n", port, getpid());
    
    while (1) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        int client_socket = accept(server_socket, (struct sockaddr*)&client_addr, &client_len);
        
        int* client_ptr = malloc(sizeof(int));
        *client_ptr = client_socket;
        
        pthread_t thread;
        pthread_create(&thread, NULL, client_handler, client_ptr);
        pthread_detach(thread);
    }
    
    return 0;
}
```

### 1.2 Update Makefile

Add the new target to `Makefile`:

```makefile
# Add to TARGETS line
TARGETS = search.cgi auth.cgi users.cgi

# Add new build rule
users.cgi: users.c
	$(CC) $(CFLAGS) -o $@ $<
	@echo "✓ Built users.cgi"
```

## Step 2: Update YARP Configuration

### 2.1 Add Route to `proxy/CGIProxy/appsettings.json`

Add to the `Routes` section:

```json
"users-route": {
  "ClusterId": "users-cluster",
  "Match": {
    "Path": "/api/users/{**catch-all}"
  },
  "Transforms": [
    { "PathRemovePrefix": "/api/users" }
  ],
  "Metadata": {
    "Service": "users"
  }
}
```

### 2.2 Add Cluster to `appsettings.json`

Add to the `Clusters` section:

```json
"users-cluster": {
  "LoadBalancingPolicy": "RoundRobin",
  "HealthCheck": {
    "Active": {
      "Enabled": true,
      "Interval": "00:00:10",
      "Timeout": "00:00:05",
      "Policy": "ConsecutiveFailures",
      "Path": "/?user=health"
    }
  },
  "Destinations": {
    "users-1": {
      "Address": "http://127.0.0.1:8003/"
    },
    "users-2": {
      "Address": "http://127.0.0.1:8004/"
    }
  }
}
```

### 2.3 Update Root Endpoint

In `proxy/CGIProxy/Program.cs`, update the endpoints array:

```csharp
endpoints = new[] { 
    "/api/metrics", 
    "/api/process", 
    "/admin", 
    "/health", 
    "/api/search", 
    "/api/auth",
    "/api/users"    // Add this line
}
```

## Step 3: Update Pool Manager

### 3.1 Update `pool_manager.py`

Add the new service to the pools configuration:

```python
# Add to the pools dictionary
pools = {
    'search': {
        'command': './search.cgi',
        'ports': [8000, 8001],
        'min_processes': 2,
        'max_processes': 5,
        'health_check': '/?q=health'
    },
    'auth': {
        'command': './auth.cgi',
        'ports': [8002],
        'min_processes': 1,
        'max_processes': 3,
        'health_check': '/?user=health'
    },
    'users': {                           # Add this block
        'command': './users.cgi',
        'ports': [8003, 8004],
        'min_processes': 1,
        'max_processes': 3,
        'health_check': '/?user=health'
    }
}
```

## Step 4: Update Process Monitoring

### 4.1 Update `RequestLoggingMiddleware.cs`

Add service detection for the new service:

```csharp
// In the InvokeAsync method, add:
else if (context.Request.Path.StartsWithSegments("/api/users"))
{
    requestMetric.Service = "users";
}
```

### 4.2 Update `ProcessMonitorService.cs`

Update the process detection regex:

```csharp
// Update the regex pattern in GetCGIProcesses method
Arguments = "-c \"ps aux | grep -E '(search|auth|users).cgi' | grep -v grep\"",

// Update the name detection logic
var name = cmdLine.Contains("search.cgi") ? "search" : 
          cmdLine.Contains("auth.cgi") ? "auth" : 
          cmdLine.Contains("users.cgi") ? "users" : "unknown";
```

Update the pool configuration:

```csharp
// In UpdatePools method
_pools[poolConfig.Key] = new PoolInfo 
{ 
    Name = poolConfig.Key,
    MinProcesses = poolConfig.Key == "search" ? 2 : 1,
    MaxProcesses = poolConfig.Key == "search" ? 5 : 3
};
```

## Step 5: Build and Test

### 5.1 Build the New Service

```bash
make users.cgi
# or
make all
```

### 5.2 Start the System

```bash
# Terminal 1: Start pool manager
make run-pool

# Terminal 2: Start YARP proxy
make run-yarp
```

### 5.3 Test the New Service

```bash
# Test the new users service
curl "http://localhost:8080/api/users?user=testuser"

# Check metrics include the new service
curl "http://localhost:8080/api/metrics/summary"

# Check process monitoring
curl "http://localhost:8080/api/process"

# View admin dashboard
# Open http://localhost:8080/admin in browser
```

## Step 6: Verify Integration

### 6.1 Check Load Balancing

```bash
# Make multiple requests to see different PIDs
for i in {1..4}; do
  curl -s "http://localhost:8080/api/users?user=test$i" | jq '.pid'
done
```

### 6.2 Check Health Monitoring

```bash
# Verify health checks are working
curl "http://localhost:8080/api/process/users"
```

### 6.3 Check Admin Dashboard

Visit `http://localhost:8080/admin` and verify:
- New service appears in process monitoring
- Metrics include requests to the new service
- Health status shows as healthy

## Example Complete Configuration

Here's what the complete `appsettings.json` would look like with the new users service:

```json
{
  "ReverseProxy": {
    "Routes": {
      "search-route": { /* existing search route */ },
      "auth-route": { /* existing auth route */ },
      "users-route": {
        "ClusterId": "users-cluster",
        "Match": { "Path": "/api/users/{**catch-all}" },
        "Transforms": [{ "PathRemovePrefix": "/api/users" }],
        "Metadata": { "Service": "users" }
      }
    },
    "Clusters": {
      "search-cluster": { /* existing search cluster */ },
      "auth-cluster": { /* existing auth cluster */ },
      "users-cluster": {
        "LoadBalancingPolicy": "RoundRobin",
        "HealthCheck": {
          "Active": {
            "Enabled": true,
            "Interval": "00:00:10",
            "Timeout": "00:00:05",
            "Policy": "ConsecutiveFailures",
            "Path": "/?user=health"
          }
        },
        "Destinations": {
          "users-1": { "Address": "http://127.0.0.1:8003/" },
          "users-2": { "Address": "http://127.0.0.1:8004/" }
        }
      }
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure new ports (8003, 8004) aren't in use
2. **Health check failures**: Verify the health check path returns 200
3. **Route conflicts**: Ensure the new route path doesn't conflict with existing routes
4. **Process monitoring**: Check that the regex pattern includes your new service

### Debugging Commands

```bash
# Check if ports are available
netstat -tuln | grep -E '800[3-4]'

# Test health check directly
curl "http://localhost:8003/?user=health"

# Check YARP logs
# Look at console output from make run-yarp

# Check pool manager logs
# Look at console output from make run-pool
```

This guide provides everything needed to add new service pools to your YARP-based CGI process pool architecture!