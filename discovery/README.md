# Discovery Module

The service discovery and sample management system that automatically detects, registers, and manages CGI applications across multiple programming languages.

## 🎯 Purpose

This module provides centralized service discovery, automatic build rule generation, and sample application management for the CGI Process Pool system.

## 📁 Structure

```
discovery/
├── README.md           # This file
├── discovery.py        # Main discovery engine
├── manifest.json       # Service registry and sample definitions
└── samples/            # Sample applications and templates
    ├── c/              # C language samples
    ├── python/         # Python samples  
    ├── csharp/         # C# script samples
    └── templates/      # Reusable service templates
```

## 🚀 Quick Start

### Discovery Commands
```bash
# List all discovered services
./discovery/discovery.py list

# Show services by language
./discovery/discovery.py list --language python
./discovery/discovery.py list --language csharp

# Get detailed service information
./discovery/discovery.py info --name search
./discovery/discovery.py info --name python_cgi
```

### Build System Integration
```bash
# Generate build rules (called automatically by Makefile)
./discovery/discovery.py rules

# Generate pool configuration
./discovery/discovery.py pool-config
```

## 🔧 Core Components

### **discovery.py**
- Service detection and registration
- Dynamic build rule generation
- Pool configuration management
- Multi-language sample discovery
- Command-line interface for service management

### **manifest.json**
- Centralized service registry
- Sample application metadata
- Language-specific configurations
- API endpoint definitions
- Health check specifications
- Example usage patterns

### **samples/ Directory**
Sample applications organized by language:
- **C**: `search.c`, `auth.c` - High-performance compiled services
- **Python**: `sample_python_cgi.py` - Full-featured HTTP server with threading
- **C#**: `sample_csharp_cgi.csx` - Async script with dotnet-script runtime

## 📋 Service Registry (manifest.json)

### Service Definition Format
```json
{
  "samples": {
    "service_name": {
      "name": "Display Name",
      "description": "Service description",
      "language": "c|python|csharp",
      "type": "core|template",
      "path": "samples/language/file.ext",
      "executable": "output_name.ext",
      "default_ports": [8000, 8001],
      "health_check": "/?param=health",
      "api_endpoint": "/api/service_name",
      "examples": [
        "curl \"http://localhost:8080/api/service_name?param=value\""
      ],
      "features": ["Feature list"]
    }
  }
}
```

### Supported Languages
| Language | File Extension | Runtime | Build Required |
|----------|----------------|---------|----------------|
| C | `.c` | Compiled binary | Yes |
| Python | `.py` | `python3` | No |
| C# Script | `.csx` | `dotnet-script` | No |

## 🔍 Discovery Features

### **Automatic Detection**
- Scans manifest.json for service definitions
- Detects language-specific samples
- Generates build rules dynamically
- Creates pool manager configurations

### **Build System Integration**
- Generates `Makefile.rules` automatically
- Creates language-specific build targets
- Handles dependencies and compilation
- Supports mixed-language projects

### **Service Management**
- Centralized service registry
- Metadata and documentation
- Health check definitions
- API endpoint mapping
- Example usage patterns

## 🧪 Sample Applications

### **search.c** (C Language)
- High-performance search API
- Query parameter handling
- JSON response generation
- Process identification
- Load balancing ready

### **sample_python_cgi.py** (Python)
- Full HTTP server implementation
- GET/POST request handling
- Threading support
- Signal handling
- CORS headers
- JSON request/response processing

### **sample_csharp_cgi.csx** (C# Script)
- Async/await HTTP server
- dotnet-script runtime
- NuGet package support
- TcpListener implementation
- JSON serialization
- Signal handling

## 🔧 Adding New Services

### 1. Add Service Definition
Update `manifest.json`:
```json
{
  "samples": {
    "my_service": {
      "name": "My Service",
      "description": "Service description",
      "language": "python",
      "path": "samples/python/my_service.py",
      "executable": "my_service.py", 
      "default_ports": [8010],
      "health_check": "/?health=true",
      "api_endpoint": "/api/my_service"
    }
  }
}
```

### 2. Create Service Implementation
```bash
# Create the service file
vim discovery/samples/python/my_service.py

# Test discovery
./discovery/discovery.py list
./discovery/discovery.py info --name my_service
```

### 3. Build and Test
```bash
# Generate build rules
make clean && make all

# Test the service
make smoke-test
```

## 🔌 Integration Points

### **Build System** (`../Makefile`)
- Automatic target discovery: `TARGETS := $(shell ./discovery/discovery.py targets)`
- Dynamic rule generation: `-include Makefile.rules`
- Language-agnostic building

### **Pool Manager** (`../pool/`)
- Service configuration export
- Port and instance management
- Health check integration

### **Testing Suite** (`../testing/`)
- Automatic test discovery
- Smoke test integration
- Stress test participation

### **YARP Proxy** (`../proxy/`)
- Route configuration
- Load balancing setup
- Health monitoring

## 📊 Monitoring and Health Checks

Each service defines:
- **Health Check Endpoint**: Custom health verification
- **API Endpoint**: Service access point
- **Example Requests**: Usage demonstrations
- **Feature Documentation**: Capability listing

## 🔗 Command Reference

```bash
# Discovery operations
./discovery/discovery.py list [--language LANG] [--format text|json]
./discovery/discovery.py info --name SERVICE_NAME
./discovery/discovery.py targets
./discovery/discovery.py rules
./discovery/discovery.py pool-config

# Makefile integration
make discover          # List all services
make discover-python   # Python services only
make discover-csharp   # C# services only
make sample-info SAMPLE=service_name
```

The discovery system provides the foundation for automatic service management, enabling the CGI Process Pool to scale across multiple languages and service types seamlessly.