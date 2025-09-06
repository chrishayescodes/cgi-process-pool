# CGI Process Pool Architecture

## Overview
Modern CGI-style architecture with YARP reverse proxy, comprehensive monitoring, and load balancing.

## Architecture Components

### 1. CGI Process Pool
- **Search Service**: C-based processes on ports 8000-8001
- **Auth Service**: C-based process on port 8002  
- **Pool Manager**: Python service managing process lifecycle

### 2. YARP Reverse Proxy (Port 8080)
- **Load Balancing**: Round-robin across CGI processes
- **Health Monitoring**: Active health checks every 10 seconds
- **Request Tracking**: Comprehensive middleware capturing all requests
- **Cross-cutting Concerns**: Logging, metrics, error handling

### 3. Admin Portal (Port 5000)
- **Process Monitoring**: Real-time status of CGI processes
- **SignalR Integration**: Live updates to dashboard
- **Background Services**: Continuous health monitoring

## Request Flow
```
Client Request → YARP Proxy (8080) → CGI Processes (8000-8002) → Response
                      ↓
              Request Logging Middleware
                      ↓  
              Metrics Collection & Storage
```

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