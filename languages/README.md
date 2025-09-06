# Languages Module

The modular language support system that enables adding new programming languages to the CGI Process Pool with minimal configuration.

## 🎯 Purpose

This module provides a unified interface for managing multiple programming languages, automatically generating automation scripts, and maintaining language-specific configurations.

## 📁 Structure

```
languages/
├── README.md                     # This file
├── definitions.json              # Language configurations  
├── manager.py                    # Core language management engine
├── add_service.sh               # Universal service generator
├── generators/                   # Auto-generated scripts
│   ├── add_c_cgi_app.sh
│   ├── add_python_cgi_app.sh
│   ├── add_csharp_cgi_app.sh
│   └── ...
└── examples/
    └── add_javascript_language.py # Example: adding new languages
```

## 🚀 Quick Start

### Adding a Service
```bash
# Add a new service in any supported language
./languages/add_service.sh python analytics 8007 3
./languages/add_service.sh csharp orders 8009 2
./languages/add_service.sh c search 8000 2
```

### Managing Languages
```bash
# List all supported languages
./languages/manager.py list

# Get language details
./languages/manager.py info --language python

# Generate automation script for a language
./languages/manager.py generate-script --language csharp --output temp_script.sh
```

## 🔧 Core Components

### **manager.py**
- Language configuration management
- Template-based automation script generation
- Service discovery system integration
- YARP configuration updates

### **definitions.json**
- Language-specific configurations
- Runtime commands and requirements
- Health check patterns
- Monitoring and logging configurations

### **add_service.sh**
- Universal language service generator
- Automatically detects supported languages
- Generates and executes language-specific scripts
- Provides unified interface across all languages

## 🎨 Supported Languages

| Language | Extension | Runtime | Build Required |
|----------|-----------|---------|----------------|
| C | `.c` | Compiled binary | Yes |
| Python | `.py` | `python3` | No |
| C# Script | `.csx` | `dotnet-script` | No |

## 🔌 Adding New Languages

### 1. Define Language Configuration
Add to `definitions.json`:
```json
{
  "languages": {
    "your_language": {
      "name": "Your Language",
      "description": "Description here",
      "file_extension": ".ext",
      "executable_extension": ".ext",
      "build_required": false,
      "runtime": {
        "command": "runtime {executable}",
        "health_check": "/?health=check"
      }
    }
  }
}
```

### 2. Generate Automation Script
```bash
./languages/manager.py generate-script --language your_language --output add_your_language_cgi_app.sh
```

### 3. Test Integration
```bash
./languages/add_service.sh your_language test_service 8020 2
```

## 🔍 Features

- **Template-Based Generation**: Automatic script generation from configurations
- **YARP Integration**: Automatic load balancer and health check setup
- **Process Monitoring**: Integrated with admin dashboard
- **Health Checks**: Language-specific health monitoring
- **Extensible Design**: Easy to add new languages
- **Backward Compatibility**: Maintains existing interfaces

## 🧪 Testing

Languages are automatically detected and included in:
- Smoke tests: `make smoke-test`
- Stress tests: `./testing/stress_test.sh`
- Unit tests: `make test`

## 📖 Examples

See `examples/add_javascript_language.py` for a complete example of adding JavaScript/Node.js and Rust support to the system.

## 🔗 Integration

This module integrates with:
- **Discovery System**: `../discovery/` for service registration
- **Pool Manager**: `../pool/` for process lifecycle management  
- **Testing Suite**: `../testing/` for automated testing
- **YARP Proxy**: `../proxy/` for load balancing and routing