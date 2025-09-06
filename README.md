# CGI Process Pool with YARP Proxy

A modern implementation of CGI-style process pools using YARP (Yet Another Reverse Proxy) for load balancing, health monitoring, and comprehensive observability.

## ✨ Features

- **🔧 CGI Process Pool**: C-based HTTP servers with socket communication
- **🐍 Python CGI Support**: Full Python integration with automated tooling
- **🔷 C# Script Support**: C# script execution with dotnet-script runtime
- **⚡ YARP Reverse Proxy**: Modern .NET-based load balancing and routing  
- **📊 Integrated Admin Dashboard**: Real-time monitoring with live metrics
- **🔄 Load Balancing**: Round-robin distribution with health checks
- **📈 Request Tracking**: Detailed metrics and analytics
- **🔍 Dynamic Discovery**: Automatic sample detection and configuration from JSON manifest
- **🚀 Automated Service Addition**: One-command CGI app integration (C, Python & C#)
- **🏥 Health Monitoring**: Automatic failover and process management

## 🚀 Quick Start

### 1. Check Dependencies
```bash
make check-deps
```

### 2. Discover and Build Services
```bash
# Discover available samples
make discover

# Get details about a specific sample
make sample-info SAMPLE=search

# Build all discovered services
make all
```

### 3. Run the System
```bash
# Terminal 1: Start process pool (auto-configured from manifest.json)
make run-pool

# Terminal 2: Start YARP proxy with admin dashboard  
make run-yarp
```

### 4. Access Your System
- **🌐 Admin Dashboard**: http://localhost:8080/admin
- **📊 API Metrics**: http://localhost:8080/api/metrics  
- **🔍 Search API**: http://localhost:8080/api/search?q=test
- **🔐 Auth API**: http://localhost:8080/api/auth?user=demo
- **🔷 C# Script API**: http://localhost:8080/api/csharp?service=demo

## 🤖 Adding New Services (Automated)

Add a complete new CGI service with one command:

```bash
# Add a C-based "orders" service with 2 instances on ports 8005-8006
./add_cgi_app.sh orders 8005 2

# Add a Python-based "analytics" service with 3 instances  
./add_python_cgi_app.sh analytics 8007 3

# Add a C# script-based "orders" service with 2 instances
./add_csharp_cgi_app.sh orders 8009 2
```

**What this does automatically:**
- ✅ Creates complete C, Python, or C# script source code
- ✅ Updates YARP configuration 
- ✅ Configures load balancing and health checks
- ✅ Integrates with admin dashboard
- ✅ Builds and tests the service

## 🔍 Dynamic Discovery System

The build system automatically discovers applications from the JSON manifest and configures everything dynamically:

### Discovery Commands
```bash
# List all available applications
make discover

# Filter by language
make discover-c         # C applications only
make discover-python    # Python applications only  
make discover-csharp    # C# script applications only  

# Get detailed information about an application
make sample-info SAMPLE=search

# Show pool manager configuration
make pool-config
```

### Adding New Applications
1. Place your source anywhere (apps can live anywhere)
2. Add entry to `manifest.json`:
```json
{
  "my_service": {
    "name": "My Service",
    "description": "Description here", 
    "language": "c",        // or "python", "csharp"
    "type": "core",
    "path": "src/my_service.c",     // .py or .csx for other languages
    "executable": "my_service.cgi", // .py or .csx for other languages  
    "default_ports": [8005, 8006]
  }
}
```
3. Run `make` to auto-build and integrate

**Discovery Features:**
- ✅ Automatic build rule generation
- ✅ Dynamic pool configuration  
- ✅ Language-agnostic integration
- ✅ Self-documenting applications
- ✅ Zero manual configuration

## 🧪 Testing

### API Tests
```bash
# Test services
curl "http://localhost:8080/api/search?q=test"
curl "http://localhost:8080/api/auth?user=demo"
curl "http://localhost:8080/api/csharp?service=demo"

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

### Stress Testing
```bash
# Run comprehensive stress test
./stress_test.sh

# Custom stress test parameters
./stress_test.sh -c 100 -t 500 -d 60  # 100 concurrent, 500 total, 60s duration
```

**Stress Test Features:**
- Load balancing verification
- Concurrent request testing (default: 50)
- Sustained load testing (default: 30s)
- Health endpoint validation
- Response time statistics
- Colored progress indicators

## 📁 Project Structure

```
cgi-process-pool/
├── 📦 Sample Applications
│   ├── .samples/                # Sample registry and applications
│   │   ├── manifest.json        # Editable sample manifest
│   │   ├── c/                   # C language samples
│   │   ├── python/              # Python language samples
│   │   ├── csharp/              # C# script samples  
│   │   └── templates/           # Service templates
├── 🔧 Core Services
│   └── pool_manager.py          # Process lifecycle manager
├── 🌐 YARP Proxy
│   └── proxy/CGIProxy/          # Reverse proxy + admin UI
├── 🏗️ Build Output
│   └── build/                   # Compiled CGI executables (gitignored)
├── 🤖 Automation
│   ├── add_cgi_app.sh          # C service automation
│   ├── add_python_cgi_app.sh   # Python service automation
│   ├── add_csharp_cgi_app.sh   # C# script service automation
│   ├── stress_test.sh          # Comprehensive load testing
│   └── check_dependencies.sh   # System requirements checker
├── 📚 Documentation  
│   └── .docs/                   # Comprehensive guides
└── ⚙️ Build System
    ├── Makefile                 # Build automation with organized output
    └── demo.sh                  # Legacy demo
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[Architecture Guide](.docs/ARCHITECTURE.md)** | System architecture and components |
| **[Sample Applications](.samples/README.md)** | Complete sample registry and usage guide |
| **[Adding CGI Apps](.docs/ADDING_CGI_APPS.md)** | Automated C service integration guide |
| **[Python CGI Integration](.docs/PYTHON_CGI_INTEGRATION.md)** | Complete Python service integration guide |
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
# Sample Management
make samples         # List available samples
make samples-info    # Show detailed sample manifest

# Build and test
make all             # Build all CGI services to build/ directory
make test            # Run basic functionality tests  
make clean           # Clean build/ directory and artifacts
./stress_test.sh     # Run comprehensive stress test

# Run system
make run-pool        # Start CGI process pool
make run-yarp        # Start YARP proxy with admin dashboard
make run-demo        # Legacy nginx demo

# Add services  
./add_cgi_app.sh <name> <port> [instances]           # Add C service
./add_python_cgi_app.sh <name> <port> [instances]   # Add Python service
./add_csharp_cgi_app.sh <name> <port> [instances]   # Add C# script service

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
- **.NET 8 SDK**: YARP proxy and C# script support
- **dotnet-script**: For C# script execution (`dotnet tool install -g dotnet-script`)
- **curl + jq**: Testing tools (optional)
- **bash**: For automation scripts

## 🏆 Performance

Based on stress testing results:
- **Response Time**: Average 9ms (min: 4ms, max: 14ms)
- **Concurrency**: 100% success rate with 50 concurrent requests
- **Throughput**: 24+ requests/second sustained
- **Reliability**: 0 errors during 30-second sustained load test
- **Scalability**: Automatic process scaling based on load

## 🎯 Perfect For

- **Learning**: Modern CGI and reverse proxy concepts
- **Development**: Fast HTTP service prototyping in C, Python, and C#
- **Architecture**: Microservice patterns with observability
- **Integration**: .NET ecosystem with multi-language service support

This project demonstrates how to build modern, observable CGI-style architectures with comprehensive monitoring and automated service management.