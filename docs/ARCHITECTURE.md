# How this thing actually works

## The basic idea

So I wanted to see what happens if you take the old CGI model (spawn a process per request) but make it smarter. Instead of spawning fresh processes every time, we keep pools of them running and load balance between them.

The twist? I used YARP (Microsoft's reverse proxy) to handle all the routing instead of nginx. Turns out it's pretty flexible for this kind of experiment.

## What's running where

### The worker processes
These are the actual CGI services doing the work:
- **Search service**: Some C code that handles search queries (ports 8000-8001, because load balancing)
- **Auth service**: Also C, handles authentication stuff (port 8002)  
- **Python service**: Because sometimes you want Python for things (port 8003)
- **C# script service**: Using dotnet-script for C# without compilation (port 8004)
- **C# abstraction service**: The fancy one Claude helped me build (port 8005)

A Python script (pool manager) babysits all these processes - restarts them when they crash, assigns ports dynamically, keeps track of what's healthy.

### YARP proxy (Port 8080)
This is where all requests come in. YARP handles:
- **Routing**: `/api/search` goes to search processes, `/api/auth` goes to auth, etc.
- **Load balancing**: Multiple search processes? Round-robin between them
- **Health checks**: Pings processes every 10 seconds, removes unhealthy ones
- **Metrics**: Tracks response times, success rates, all that good stuff

### Admin dashboard
Built into YARP, shows you what's happening in real-time. Nothing fancy, just useful.

## Request Flow
```
Client Request → YARP Proxy (8080) → CGI Processes (8000-8005) → Response
                      ↓
              Request Logging Middleware
                      ↓  
              Metrics Collection & Storage
```

## The port management thing

One annoying problem I kept hitting: port conflicts. You know how it goes - "Error: port 8080 already in use" and then you spend 10 minutes hunting down what's using it.

So Claude and I built a system that figures this out automatically:

### How it works
1. **Build time**: When you run `make all`, it cleans everything first, then generates a YARP config based on what *should* be running
2. **Runtime**: The pool manager starts services, finds available ports, and writes the actual port assignments to `/tmp/cgi_ports.json`
3. **Next build**: YARP config generation reads the runtime ports if they exist, falls back to defaults if not

This means:
- No more port conflicts between services
- The system adapts to whatever ports are actually available
- Clean builds work from any state
- You can see what's actually running vs what's configured

The Python script is pretty simple - it just scans for available ports starting from the defaults and updates the JSON file. YARP reads from that file and routes accordingly.

## Key Features

### Load Balancing
- **Strategy**: Round-robin distribution
- **Health Checks**: Automatic failover for unhealthy processes
- **Verified Working**: Requests distributed across PIDs 20021, 20032, 20180

### Request Tracking
- **Comprehensive Metrics**: Response times, status codes, service distribution
- **Live Monitoring**: Real-time request tracking with configurable time windows
- **Historical Data**: Up to 1000 recent requests stored in memory
- **Performance Analytics**: Slowest requests, success rates, throughput metrics

### Monitoring Endpoints
- `GET /api/metrics` - Overall system metrics
- `GET /api/metrics/summary` - High-level system summary  
- `GET /api/metrics/requests` - Detailed request history
- `GET /api/metrics/requests/live` - Live request tracking
- `GET /health` - System health status

## Current System Status
✅ **YARP Proxy**: Running on port 8080 with active health monitoring  
✅ **Load Balancing**: Verified across all CGI processes  
✅ **Metrics Collection**: 11+ requests tracked with detailed analytics  
✅ **Health Monitoring**: All destinations healthy (search-1, search-2, auth-1)  
✅ **Performance**: 100% success rate, average 9.3ms response time  
✅ **Admin Portal**: Available at port 5000 with real-time dashboard  

## Architecture Benefits
1. **No CGI Modification**: Request tracking without touching original processes
2. **Modern Observability**: Rich metrics and monitoring capabilities  
3. **High Availability**: Automatic failover and health monitoring
4. **Scalability**: Easy to add more CGI process instances
5. **Cross-cutting Concerns**: Centralized logging, metrics, and error handling

## Configuration
- **YARP Routes**: Configured in `proxy/CGIProxy/appsettings.json`
- **Health Checks**: Custom paths per service (`/?q=health`, `/?user=health`)
- **Logging**: Structured logging with Serilog to console and files
- **CORS**: Enabled for admin portal integration