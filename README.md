# CGI Process Pool with YARP Proxy

A modern implementation of CGI-style process pools using YARP (Yet Another Reverse Proxy) for load balancing, health monitoring, and comprehensive observability.

## ✨ Features

- **🔧 CGI Process Pool**: C-based HTTP servers with socket communication
- **⚡ YARP Reverse Proxy**: Modern .NET-based load balancing and routing  
- **📊 Integrated Admin Dashboard**: Real-time monitoring with live metrics
- **🔄 Load Balancing**: Round-robin distribution with health checks
- **📈 Request Tracking**: Detailed metrics and analytics
- **🚀 Automated Service Addition**: One-command CGI app integration
- **🏥 Health Monitoring**: Automatic failover and process management

## 🚀 Quick Start

### 1. Check Dependencies
```bash
make check-deps
```

### 2. Build and Run
```bash
# Build all services
make all

# Terminal 1: Start process pool
make run-pool

# Terminal 2: Start YARP proxy with admin dashboard  
make run-yarp
```

### 3. Access Your System
- **🌐 Admin Dashboard**: http://localhost:8080/admin
- **📊 API Metrics**: http://localhost:8080/api/metrics  
- **🔍 Search API**: http://localhost:8080/api/search?q=test
- **🔐 Auth API**: http://localhost:8080/api/auth?user=demo

## 🤖 Adding New Services (Automated)

Add a complete new CGI service with one command:

```bash
# Add an "orders" service with 2 instances on ports 8005-8006
./add_cgi_app.sh orders 8005 2

# Add a "products" service with 3 instances  
./add_cgi_app.sh products 8007 3
```

**What this does automatically:**
- ✅ Creates complete C source code
- ✅ Updates YARP configuration 
- ✅ Configures load balancing and health checks
- ✅ Integrates with admin dashboard
- ✅ Builds and tests the service

## 🧪 Testing

### API Tests
```bash
# Test services
curl "http://localhost:8080/api/search?q=test"
curl "http://localhost:8080/api/auth?user=demo"

# Check system health
curl "http://localhost:8080/api/metrics/summary" | jq
```

### Load Balancing Verification
```bash
# See different PIDs (proves load balancing)
for i in {1..4}; do
  curl -s "http://localhost:8080/api/search?q=test$i" | jq '.pid'
done
```

## 📁 Project Structure

```
cgi-process-pool/
├── 🔧 Core Services
│   ├── search.c                 # Search CGI service
│   ├── auth.c                   # Auth CGI service  
│   └── pool_manager.py          # Process lifecycle manager
├── 🌐 YARP Proxy
│   └── proxy/CGIProxy/          # Reverse proxy + admin UI
├── 🤖 Automation
│   ├── add_cgi_app.sh          # Automated service addition
│   └── check_dependencies.sh   # System requirements checker
├── 📚 Documentation  
│   └── .docs/                   # Comprehensive guides
└── ⚙️ Build System
    ├── Makefile                 # Build automation
    └── demo.sh                  # Legacy demo
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[Architecture Guide](.docs/ARCHITECTURE.md)** | System architecture and components |
| **[Adding CGI Apps](.docs/ADDING_CGI_APPS.md)** | Automated service integration guide |
| **[Manual Pool Setup](.docs/ADDING_NEW_POOLS.md)** | Step-by-step manual process |
| **[Original POC](.docs/cgi_pool_poc.md)** | Initial proof of concept |

## 🏗️ Architecture Overview

```
Client → YARP Proxy (8080) → CGI Pool (8000-8002) → Response
            ↓
    Admin Dashboard + Metrics + Health Monitoring
```

**Key Components:**
- **YARP Proxy**: Modern reverse proxy with observability
- **CGI Services**: Fast C-based HTTP servers
- **Pool Manager**: Python service for process lifecycle
- **Admin Dashboard**: Real-time monitoring interface

## 🔧 Available Commands

```bash
# Build and test
make all              # Build all CGI services
make test            # Run basic functionality tests  
make clean           # Clean build artifacts

# Run system
make run-pool        # Start CGI process pool
make run-yarp        # Start YARP proxy with admin dashboard
make run-demo        # Legacy nginx demo

# Add services  
./add_cgi_app.sh <name> <port> [instances]

# Check system
make check-deps      # Verify dependencies
make help           # Show all available commands
```

## 📊 Monitoring Features

The system provides comprehensive observability:

- **📈 Real-time Metrics**: Request rates, response times, error rates
- **🏥 Health Monitoring**: Active health checks with automatic failover  
- **⚖️ Load Distribution**: Service usage and balancing statistics
- **🔍 Request Tracking**: Individual request tracing and correlation
- **📱 Live Dashboard**: Web-based admin interface with auto-refresh

## 🚀 Advanced Features

### Automatic Service Integration
- One command adds complete CGI service
- Full YARP route configuration
- Load balancing and health checks  
- Admin dashboard integration

### Production-Ready Monitoring
- Structured logging with Serilog
- Request correlation IDs
- Performance analytics
- Error tracking and alerting

### Modern Architecture
- .NET 8 based YARP proxy
- Multithreaded C services
- Python process management
- Clean separation of concerns

## 🏛️ Legacy Support

nginx compatibility included for migration scenarios:
```bash
make run-demo  # Run with nginx (legacy)
```

**Recommendation**: Use YARP-based approach for superior observability and modern .NET ecosystem integration.

## 📋 Requirements

- **GCC**: C compiler with pthread support
- **Python 3**: Process management  
- **.NET 8 SDK**: YARP proxy
- **curl + jq**: Testing tools (optional)

## 🎯 Perfect For

- **Learning**: Modern CGI and reverse proxy concepts
- **Development**: Fast HTTP service prototyping  
- **Architecture**: Microservice patterns with observability
- **Integration**: .NET ecosystem with C services

This project demonstrates how to build modern, observable CGI-style architectures with comprehensive monitoring and automated service management.