# CGI Process Pool - Interactive Walkthrough

## 🚀 Step-by-Step Learning Journey

This walkthrough takes you through the system from the ground up, with hands-on exercises to understand each concept.

## Phase 1: Understanding the Basics (15 minutes)

### Step 1: Start Simple - Single HTTP Server
Let's begin by understanding how a basic HTTP server works:

```bash
# Build and run a single CGI service
make all
./build/search.cgi 9000 &

# Test it directly (bypassing the proxy)
curl "http://localhost:9000/?q=test"
```

**What you should see:**
```json
{
  "query": "test",
  "results": [{"id": 1, "title": "Test Result"}],
  "pid": 12345,
  "port": 9000
}
```

**Key Learning:** 
- The `pid` changes if you kill and restart the process
- The process is listening on a specific port
- It's parsing HTTP requests and generating JSON responses

### Step 2: Examine the Code
Open `discovery/samples/c/search.c` and find these key parts:

1. **Socket Creation** (line ~40):
   ```c
   int server_fd = socket(AF_INET, SOCK_STREAM, 0);
   ```

2. **HTTP Request Parsing** (line ~80):
   ```c
   sscanf(buffer, "%s %s %s", method, path, version);
   ```

3. **JSON Response Generation** (line ~120):
   ```c
   sprintf(response, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{...}");
   ```

**Exercise:** Modify the response to include your name, then rebuild and test!

### Step 3: See What Manual Process Management Looks Like
```bash
# Start multiple processes manually (the old way)
./build/search.cgi 8000 &
./build/search.cgi 8001 &  
./build/auth.cgi 8002 &

# Check what's running
ps aux | grep "\.cgi" | grep -v grep

# Test each one
curl "http://localhost:8000/?q=manual"
curl "http://localhost:8001/?q=manual"  
curl "http://localhost:8002/?user=manual"

# Kill them all (cleanup)
pkill -f "\.cgi"
```

**Key Learning:** This is tedious and error-prone! We need better process management.

## Phase 2: Process Pool Management (20 minutes)

### Step 4: The Process Pool Manager
Now let's see how the pool manager makes this easier:

```bash
# Start the pool manager (it will spawn processes automatically)
python3 pool/manager.py &

# Watch it work
sleep 3
ps aux | grep "\.cgi" | grep -v grep
```

**What you should see:**
- Multiple processes automatically started
- Each on a different port
- All managed by the pool manager

### Step 5: Examine Pool Manager Code
Open `pool/manager.py` and find:

1. **Process Spawning** (`spawn_process()` method):
   ```python
   process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
   ```

2. **Health Checking** (`health_check()` method):
   ```python
   response = requests.get(f"http://localhost:{port}?q=health", timeout=0.5)
   ```

3. **Auto-scaling** (`scale_up()` method):
   ```python
   if avg_requests > 10:
       self.spawn_process()
   ```

### Step 6: Break Things (Safely!)
Let's test the self-healing capabilities:

```bash
# Find a CGI process
ps aux | grep search.cgi | head -1

# Kill it (replace 12345 with actual PID)
kill -9 12345

# Wait a few seconds, then check
sleep 5
ps aux | grep search.cgi
```

**Key Learning:** The pool manager detected the dead process and started a new one!

## Phase 3: Load Balancing & Reverse Proxy (25 minutes)

### Step 7: Add the Reverse Proxy
Now let's add YARP to handle load balancing:

```bash
# Start YARP proxy (in new terminal)
cd proxy/CGIProxy && dotnet run --urls="http://0.0.0.0:8080"
```

Wait for it to start, then test:

```bash
# This request goes through the proxy to the backend pool
curl "http://localhost:8080/api/search?q=proxy-test"
```

### Step 8: Observe Load Balancing
Run several requests and watch the load balancing:

```bash
# Run 10 requests and see different PIDs
for i in {1..10}; do
  echo "Request $i:"
  curl -s "http://localhost:8080/api/search?q=test$i" | jq '.pid'
  sleep 0.1
done
```

**Key Learning:** The requests are being distributed across different processes!

### Step 9: Explore the Admin Dashboard
Open your browser to: http://localhost:8080/admin

You should see:
- System overview
- Process status
- Request metrics
- Real-time monitoring

Try making some API requests and watch the dashboard update!

### Step 10: Examine YARP Configuration
Look at `proxy/CGIProxy/appsettings.json`:

```json
{
  "ReverseProxy": {
    "Routes": {
      "search": {
        "ClusterId": "search_cluster",
        "Match": {
          "Path": "/api/search/{**catch-all}"
        }
      }
    },
    "Clusters": {
      "search_cluster": {
        "Destinations": {
          "destination1": {
            "Address": "http://127.0.0.1:8000/"
          }
        }
      }
    }
  }
}
```

**Exercise:** Can you figure out how to add a new route?

## Phase 4: Modern Process Management (15 minutes)

### Step 11: Use the Hardened Process Management
Stop everything and try the new unified system:

```bash
# Stop everything the old way
pkill -f "pool/manager.py"
pkill -f "dotnet run"
pkill -f "\.cgi"

# Start everything the new way  
make start-bg

# Check status
make status
```

### Step 12: Test the Complete System
```bash
# Run smoke tests
make smoke-test

# Run stress tests  
./testing/stress_test.sh -c 20 -t 100

# Check status again
make status
```

### Step 13: Experience Graceful Shutdown
```bash
# Stop everything cleanly
make stop

# Verify everything is gone
ps aux | grep -E "(pool/manager|dotnet run|\.cgi)" | grep -v grep
```

**Key Learning:** No orphaned processes! Clean shutdown!

## Phase 5: Multi-Language Services (20 minutes)

### Step 14: Add a Python Service
```bash
# Start the system
make start-bg

# Test the Python service
curl "http://localhost:8080/api/python?service=demo&data=test"
```

Compare the response format with the C service:
```bash
curl "http://localhost:8080/api/search?q=test"
```

### Step 15: Add a C# Script Service  
```bash
# Test the C# service
curl "http://localhost:8080/api/csharp?service=demo&data=test"
```

**Key Learning:** Different languages, same interface pattern!

### Step 16: Examine Language Integration
Look at the manifest file: `discovery/manifest.json`

See how different languages are configured:
- C services compile to `.cgi` executables
- Python services run with `python3` interpreter  
- C# services run with `dotnet-script` runtime

## Phase 6: Build Your Own Service (30 minutes)

### Step 17: Create a Calculator Service
Let's build a new service from scratch!

```bash
# Copy the tutorial calculator service
cp .docs/TUTORIAL_BUILD_SERVICE.md calculator.c

# Build it
gcc -o calculator calculator.c -pthread -O2

# Test it manually first  
./calculator 8005 &
curl "http://localhost:8005/?op=add&a=10&b=5"
curl "http://localhost:8005/?op=divide&a=20&b=4"
```

### Step 18: Integrate Your Service
Add it to the discovery system:

1. **Add to manifest** (`discovery/manifest.json`):
```json
{
  "calculator": {
    "name": "Calculator Service",
    "description": "Basic math operations API",
    "language": "c",
    "type": "core", 
    "path": "calculator.c",
    "executable": "calculator.cgi",
    "default_ports": [8005, 8006],
    "health_check": "/?op=add&a=1&b=1",
    "api_endpoint": "/api/calc",
    "examples": [
      "curl \"http://localhost:8080/api/calc?op=add&a=10&b=5\"",
      "curl \"http://localhost:8080/api/calc?op=multiply&a=7&b=8\""
    ],
    "features": [
      "Basic arithmetic operations",
      "Input validation",
      "Error handling"
    ]
  }
}
```

2. **Rebuild the system**:
```bash
make clean
make all
```

3. **Update proxy configuration** (this would be done automatically in a full implementation):
Add route to `proxy/CGIProxy/appsettings.json`

### Step 19: Test Your Integration
```bash
# Restart the system to pick up changes
make restart

# Test your new service
curl "http://localhost:8080/api/calc?op=add&a=15&b=25"
curl "http://localhost:8080/api/calc?op=multiply&a=6&b=7"

# Test error handling
curl "http://localhost:8080/api/calc?op=divide&a=10&b=0"
```

## Phase 7: Advanced Experiments (Bonus)

### Experiment 1: Load Testing
```bash
# Generate significant load
./testing/stress_test.sh -c 50 -t 500 -d 60

# Watch the system respond:
# - Monitor dashboard: http://localhost:8080/admin
# - Check process status: make status
# - Watch system resources: htop
```

### Experiment 2: Failure Recovery
```bash
# Kill backend processes and watch recovery
make status  # Note the PIDs
kill -9 <some_cgi_pid>
kill -9 <another_cgi_pid>

# Wait and check
sleep 10
make status  # Should show new PIDs (recovery!)
```

### Experiment 3: Configuration Changes
```bash
# Modify pool configuration
vim ops/process_config.json
# Change startup_delay, health_check timeouts, etc.

make restart
# Observe different behavior
```

## 🎓 What You've Learned

After completing this walkthrough, you've experienced:

### System Programming Concepts
- ✅ TCP socket programming and HTTP protocol
- ✅ Process creation and lifecycle management  
- ✅ Inter-process communication and coordination
- ✅ Signal handling and graceful shutdown

### Web Architecture Patterns
- ✅ Load balancing and reverse proxy concepts
- ✅ Health checking and automatic failover
- ✅ Service discovery and configuration management
- ✅ Multi-language service integration

### Production Operations
- ✅ Process monitoring and auto-scaling
- ✅ Graceful startup and shutdown procedures
- ✅ System observability and debugging
- ✅ Configuration-driven deployment

### Software Engineering Practices
- ✅ Modular system design and separation of concerns
- ✅ Testing strategies (unit, integration, load, smoke)
- ✅ Documentation and maintainability
- ✅ Version control and deployment automation

## 🚀 Next Steps

Want to dive deeper? Try:

1. **Add Authentication**: Implement API key validation
2. **Add Caching**: Redis integration for response caching
3. **Add Persistence**: Database integration for data storage
4. **Add Monitoring**: Prometheus metrics and Grafana dashboards
5. **Add Security**: Rate limiting, input validation, HTTPS
6. **Container Deployment**: Docker and Kubernetes deployment
7. **Cloud Integration**: AWS/GCP deployment with auto-scaling

## 🤝 Contributing

Found this helpful? Consider:
- Submitting improvements to the documentation
- Adding new sample services in different languages
- Creating additional tutorials for specific concepts
- Sharing your learning experience and feedback

This project demonstrates that complex systems are built from simple, understandable components. Each piece serves a clear purpose, and together they create a robust, scalable architecture that handles real-world challenges!