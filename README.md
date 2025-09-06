# CGI Process Pool with YARP Proxy

📝 **Read the Blog Post**: [The CGI Renaissance: Why Old Tech Patterns Are New Again](https://github.com/chrishayescodes/journal/blob/master/2025-09-05-cgi-renaissance-blog.md)

A modern implementation of CGI-style process pools using YARP (Yet Another Reverse Proxy) for load balancing, health monitoring, and comprehensive observability.

**🎓 Educational Focus**: This project serves as a comprehensive learning platform for systems programming, web architecture, and distributed systems concepts. Perfect for understanding how modern web infrastructure works from the ground up!

**💖 Support this Project**: If you find this educational resource helpful, consider supporting continued development and content creation on [Patreon](https://patreon.com/chrishayescodes).

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
- **🛠️ Hardened Process Management**: Production-ready lifecycle management with graceful shutdown
- **🧹 Orphan Process Cleanup**: Automatic detection and cleanup of stuck processes
- **📋 Unified Operations**: Single-command system startup, monitoring, and shutdown

## 🚀 Quick Start

### Simple Start (Recommended)
```bash
# Start the complete system (builds, starts pool + proxy, monitors)
make start

# Check status
make status

# Stop when done
make stop
```

### Manual Steps (If Needed)
```bash
# 1. Check dependencies
make check-deps

# 2. Discover and build services
make discover && make all

# 3. Start individual components
make run-pool     # Terminal 1
make run-yarp     # Terminal 2
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
./testing/stress_test.sh

# Run smoke tests for startup sanity check
make smoke-test

# Custom stress test parameters
./testing/stress_test.sh -c 100 -t 500 -d 60  # 100 concurrent, 500 total, 60s duration
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
├── 📦 Sample Applications & Discovery
│   ├── discovery/               # NEW: Discovery system and samples
│   │   ├── manifest.json        # Editable sample manifest
│   │   ├── discovery.py         # Discovery engine
│   │   └── samples/             # Sample applications by language
│   │       ├── c/               # C language samples
│   │       ├── python/          # Python language samples
│   │       ├── csharp/          # C# script samples  
│   │       └── templates/       # Service templates
├── 🛠️ Operations Management (NEW)
│   ├── ops/                     # Process lifecycle management
│   │   ├── process_manager.py   # Core process manager
│   │   ├── startup.sh          # Unified startup script
│   │   ├── shutdown.sh         # Graceful shutdown script
│   │   ├── process_config.json # Process configuration
│   │   └── README.md           # Operations documentation
├── 🌍 Modular Language System (NEW)  
│   ├── languages/              # Language plugin system
│   │   ├── definitions.json    # Language definitions
│   │   ├── manager.py          # Language manager
│   │   ├── add_service.sh      # Universal service generator
│   │   └── check_dependencies.sh # Dependency checker
├── 🔧 Core Services
│   └── pool/                   # Process pool management
│       └── manager.py          # Pool lifecycle manager  
├── 🌐 Proxy Systems
│   ├── proxy/                  # Modular proxy backends
│   │   ├── backends.json       # Proxy backend definitions
│   │   └── CGIProxy/           # YARP reverse proxy + admin UI
├── 🧪 Testing & Quality Assurance
│   ├── testing/               # Testing infrastructure  
│   │   ├── stress_test.sh     # Comprehensive load testing
│   │   └── smoketest.sh       # System health verification
├── 🏗️ Build Output
│   └── build/                  # Compiled CGI executables (gitignored)
├── 📚 Documentation  
│   └── .docs/                  # Comprehensive guides and architecture
└── ⚙️ Build System
    ├── Makefile                # Enhanced build automation
    ├── Makefile.rules          # Auto-generated build rules
    └── demo.sh                 # Legacy demo
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **📚 Learning & Education** ||
| **[Learning Guide](.docs/LEARNING_GUIDE.md)** | **🎓 START HERE**: Comprehensive educational guide with learning objectives |
| **[Interactive Walkthrough](.docs/WALKTHROUGH.md)** | **🚀 HANDS-ON**: Step-by-step tutorial with exercises and experiments |
| **[Core Concepts](.docs/CONCEPTS_OVERVIEW.md)** | **🧠 THEORY**: Deep dive into computer science concepts demonstrated |
| **[Tutorial: Build a Service](.docs/TUTORIAL_BUILD_SERVICE.md)** | **⚒️ PRACTICE**: Build your own calculator service from scratch |
| **📋 System Documentation** ||
| **[Architecture Guide](.docs/ARCHITECTURE.md)** | System architecture and components |
| **[Operations Management](ops/README.md)** | **NEW**: Process lifecycle management system |
| **[Modular Languages](.docs/MODULAR_LANGUAGES.md)** | **NEW**: Extensible language plugin system |
| **📄 Configuration Reference** ||
| **[Sample Applications](discovery/manifest.json)** | Sample registry with all available services |
| **[Language Definitions](languages/definitions.json)** | **NEW**: Supported programming languages |
| **[Proxy Backends](proxy/backends.json)** | **NEW**: Modular proxy system definitions |
| **🔧 Implementation Guides** ||
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

### System Lifecycle (Recommended)
```bash
# Complete system management
make start           # Start complete system (pool + proxy + monitoring)
make stop            # Gracefully stop complete system
make restart         # Restart complete system
make status          # Show status of all processes
make cleanup         # Clean up orphaned processes

# Background operation (for CI/testing)
make start-bg        # Start system in background (no monitoring)
make stop-force      # Force stop system (kills stuck processes)
```

### Development & Testing
```bash
# Sample Management
make discover        # List all available samples from manifest
make sample-info SAMPLE=search  # Get details about specific sample
make samples         # List available samples (legacy)
make samples-info    # Show detailed sample manifest

# Build and test
make all             # Build all CGI services to build/ directory
make test            # Run basic functionality tests  
make smoke-test      # Run smoke tests on all endpoints
make clean           # Clean build/ directory and artifacts
./testing/stress_test.sh  # Run comprehensive stress test

# Legacy individual component startup
make run-pool        # Start CGI process pool only
make run-yarp        # Start YARP proxy with admin dashboard only
make run-demo        # Legacy nginx demo
```

### Service Addition
```bash
# Add services with automation
./languages/add_service.sh <name> <language> <port> [instances]  # Universal service generator
./add_cgi_app.sh <name> <port> [instances]           # Add C service (legacy)
./add_python_cgi_app.sh <name> <port> [instances]   # Add Python service (legacy)
./add_csharp_cgi_app.sh <name> <port> [instances]   # Add C# script service (legacy)
```

### System Maintenance
```bash
# Dependencies and health
make check-deps      # Verify all language dependencies
make check-deps-fix  # Auto-install missing dependencies
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

### Hardened Process Management
- Graceful startup with dependency ordering
- Health monitoring with automatic restart
- Orphaned process detection and cleanup
- Signal handling and graceful shutdown

### Production-Ready Monitoring
- Structured logging with Serilog
- Request correlation IDs
- Performance analytics
- Error tracking and alerting

### Modern Architecture
- .NET 8 based YARP proxy
- Multithreaded C services
- Python process management
- Modular language plugin system
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

### 🎓 Learning & Education
- **Systems Programming**: Socket programming, process management, HTTP protocol
- **Web Architecture**: Load balancing, reverse proxies, microservices patterns
- **DevOps Concepts**: Process lifecycle, health monitoring, graceful deployment
- **Multi-Language Integration**: Polyglot programming and runtime coordination

### 🛠️ Development & Prototyping  
- **Fast HTTP Services**: Rapid prototyping in C, Python, and C#
- **Architecture Exploration**: Microservice patterns with observability
- **Performance Testing**: Load balancing and scaling behavior analysis
- **Integration Projects**: .NET ecosystem with multi-language service support

### 📚 Computer Science Education
- **Distributed Systems**: Practical implementation of theoretical concepts
- **Network Programming**: Real-world TCP/IP and HTTP protocol usage
- **Operating Systems**: Process management, IPC, and system programming
- **Software Engineering**: Configuration-driven design and modular architecture

## 🎓 Learning Outcomes

Students and practitioners will gain hands-on experience with:
- Building HTTP servers from scratch using system calls
- Understanding load balancing and reverse proxy implementations  
- Managing multi-process applications with health monitoring
- Creating production-ready deployment and lifecycle management
- Integrating multiple programming languages in a single system
- Implementing observability and monitoring in distributed systems

This project bridges the gap between theoretical computer science concepts and real-world system implementation, making it perfect for educational environments and self-directed learning.

## 💖 Support This Educational Project

This comprehensive learning resource is developed and maintained as an open educational project. If you find it valuable for learning systems programming, web architecture, or distributed systems concepts, please consider supporting continued development:

**[🎯 Support on Patreon](https://patreon.com/chrishayescodes)**

Your support helps:
- 📚 Create more educational content and tutorials
- 🔧 Add new language integrations and examples  
- 📖 Develop comprehensive learning materials
- 🎯 Maintain and improve the codebase
- 🌟 Keep the project free and open source for all learners

**Other ways to support:**
- ⭐ Star this repository on GitHub
- 🔄 Share the project with other learners
- 📝 Contribute improvements or documentation
- 💬 Provide feedback and learning suggestions