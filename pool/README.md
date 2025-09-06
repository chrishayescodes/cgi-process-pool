# Pool Module

The process pool management system that handles service lifecycle, process monitoring, and resource management for multi-language CGI applications.

## 🎯 Purpose

This module provides centralized process pool management, automatic service scaling, health monitoring, and resource optimization for the CGI Process Pool system.

## 📁 Structure

```
pool/
├── README.md           # This file
├── manager.py          # Main pool manager and service orchestrator
├── config/             # Pool configuration files
└── monitoring/         # Process monitoring utilities
```

## 🚀 Quick Start

### Starting the Pool Manager
```bash
# Start the pool manager (blocks - use separate terminal)
make run-pool

# Or run directly
python3 pool/manager.py
```

### Pool Configuration
The pool manager automatically configures services based on:
- Service definitions from `discovery/manifest.json`
- Language-specific automation scripts
- Health check specifications
- Port and instance configurations

## 🔧 Core Components

### **manager.py**
- **Service Orchestration**: Manages lifecycle of multiple CGI processes
- **Health Monitoring**: Continuous health checks and automatic restart
- **Resource Management**: Process scaling and resource optimization
- **Multi-language Support**: Handles C, Python, and C# services uniformly
- **Load Distribution**: Manages multiple instances per service
- **Graceful Shutdown**: Clean process termination on system shutdown

## 🎛️ Service Configuration

### Default Pool Configuration
```python
pools = {
    'search': {
        'command': './build/search.cgi',
        'ports': [8000, 8001],
        'min_processes': 1,
        'max_processes': 2,
        'health_check': '/?q=health'
    },
    'auth': {
        'command': './build/auth.cgi',
        'ports': [8002],
        'min_processes': 1, 
        'max_processes': 1,
        'health_check': '/?user=health'
    },
    'python_cgi': {
        'command': 'python3 ./discovery/samples/python/sample_python_cgi.py',
        'ports': [8003],
        'min_processes': 1,
        'max_processes': 1,
        'health_check': '/?service=health'
    },
    'csharp_script': {
        'command': 'dotnet-script ./discovery/samples/csharp/sample_csharp_cgi.csx',
        'ports': [8004],
        'min_processes': 1,
        'max_processes': 1,
        'health_check': '/?service=health'
    }
}
```

### Configuration Properties
- **command**: Process execution command
- **ports**: List of ports for load balancing
- **min_processes**: Minimum running instances
- **max_processes**: Maximum allowed instances  
- **health_check**: Health endpoint for monitoring

## 🔍 Features

### **Process Lifecycle Management**
- Automatic process startup and monitoring
- Health check-based restart policies
- Graceful shutdown handling
- Resource cleanup on exit

### **Multi-Language Support**
- **C Services**: Compiled binary execution
- **Python Services**: Python interpreter with module support
- **C# Scripts**: dotnet-script runtime execution
- **Extensible**: Easy to add new language runtimes

### **Health Monitoring**
- Continuous health check polling
- Automatic unhealthy process restart
- Service availability tracking
- Integration with YARP health checks

### **Load Balancing Ready**
- Multiple process instances per service
- Port-based load distribution
- Round-robin process allocation
- Automatic scaling capabilities

## 🏃 Process Management

### **Startup Process**
1. Load service configurations
2. Start minimum required instances
3. Begin health monitoring loops
4. Register signal handlers for graceful shutdown

### **Health Monitoring**
1. Periodic HTTP health checks to each service
2. Process status verification  
3. Automatic restart of failed services
4. Logging of health status changes

### **Shutdown Process**
1. Signal handler catches SIGINT/SIGTERM
2. Graceful termination of all managed processes
3. Resource cleanup and logging
4. Exit with proper status codes

## 🔧 Integration Points

### **Discovery System** (`../discovery/`)
- Reads service configurations from manifest.json
- Automatically configures new services
- Language-aware process management

### **YARP Proxy** (`../proxy/`)
- Provides backends for load balancing
- Health check endpoint integration
- Service availability reporting

### **Testing Suite** (`../testing/`)
- Process availability for smoke tests
- Service health verification
- Load testing coordination

### **Build System** (`../Makefile`)
- `make run-pool` command integration
- Dependency checking
- Service build verification

## 📊 Monitoring and Logging

### **Health Status**
- Service startup/shutdown events
- Health check pass/fail status
- Process restart notifications
- Resource usage tracking

### **Process Information**
- Process ID tracking
- Command line monitoring
- Exit status logging
- Error output capture

### **Service Metrics**
- Instance count per service
- Health check response times
- Restart frequency
- Uptime statistics

## 🧪 Testing Integration

### **Smoke Tests**
Pool manager supports smoke test verification:
- Service process availability checking
- Health endpoint validation
- Multi-instance load balancing verification

### **Stress Tests** 
Provides stable backend services for:
- High-concurrency testing
- Load balancing validation
- Performance benchmarking
- Resource usage monitoring

## 🔧 Configuration Management

### **Adding New Services**
Services are automatically added when:
1. Added to `discovery/manifest.json`
2. Language-specific scripts update `manager.py`
3. Pool manager restart picks up new configuration

### **Scaling Configuration**
Modify service configuration in `manager.py`:
```python
'my_service': {
    'command': 'runtime ./path/to/service',
    'ports': [8010, 8011, 8012],  # Multiple ports for load balancing
    'min_processes': 2,            # Always keep 2 running
    'max_processes': 5,            # Scale up to 5 under load
    'health_check': '/?health=check'
}
```

## 🔗 Commands and Operations

### **Manual Operations**
```bash
# Start pool manager
python3 pool/manager.py

# Check process status
ps aux | grep -E "(search|auth|python_cgi|csharp)"

# Test health endpoints directly
curl "http://localhost:8000/?q=health"
curl "http://localhost:8003/?service=health"
```

### **Integration with Make**
```bash
make run-pool      # Start pool manager
make smoke-test    # Test pool health
make run-yarp      # Start proxy (requires pool)
```

The pool manager provides robust, scalable process management that forms the foundation of the CGI Process Pool system, enabling reliable multi-language service orchestration.