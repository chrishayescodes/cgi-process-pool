# Modular Language System

The CGI Process Pool now supports a **modular language architecture** that makes adding new programming languages simple, consistent, and maintainable.

## 🏗️ Architecture Overview

The modular system consists of:

1. **Language Definitions** (`languages.json`) - Configuration for each supported language
2. **Language Manager** (`language_manager.py`) - Core management and generation engine  
3. **Universal Service Generator** (`add_language_service.sh`) - Single interface for all languages
4. **Auto-Generated Scripts** - Language-specific automation scripts created on demand

## 🚀 Quick Start

### Using the Universal Generator

```bash
# Add any supported language service
./add_language_service.sh <language> <app_name> <start_port> [instances]

# Examples:
./add_language_service.sh python analytics 8007 3
./add_language_service.sh csharp orders 8009 2  
./add_language_service.sh javascript api 8011 4
./add_language_service.sh rust fast_service 8013 2
```

### Managing Languages

```bash
# List all available languages
./language_manager.py list

# Get detailed info about a language
./language_manager.py info --language python

# Generate automation script for a language
./language_manager.py generate-script --language rust --output add_rust_service.sh
```

## 📋 Currently Supported Languages

| Language | Extension | Runtime | Build Required | Description |
|----------|-----------|---------|----------------|-------------|
| **C** | `.c` | `gcc + executable` | ✅ Yes | High-performance native services |
| **Python** | `.py` | `python3` | ❌ No | Rich ecosystem, rapid development |
| **C# Script** | `.csx` | `dotnet-script` | ❌ No | .NET ecosystem with scripting |
| **JavaScript** | `.js` | `node` | ❌ No | npm ecosystem, async capabilities |
| **Rust** | `.rs` | `rustc + executable` | ✅ Yes | Memory safety with performance |

## 🔧 Adding a New Language

Adding support for a new language is now incredibly simple:

### 1. Define Language Configuration

```python
from language_manager import LanguageManager

manager = LanguageManager()

# Define your language
go_config = {
    "name": "Go",
    "description": "Fast, simple, reliable Go services with excellent concurrency",
    "file_extension": ".go",
    "executable_extension": "",  # Compiled binary
    "build_required": True,
    "runtime": {
        "command": "./{executable}",
        "build_command": "go build -o {executable} {source_file}",
        "health_check": "/?health=ok",
        "requirements": ["Go compiler (go)"]
    },
    "template": {
        "imports": [
            "package main",
            "import (", 
            "    \"fmt\"",
            "    \"net/http\"",
            "    \"os\"",
            ")"
        ],
        "main_function": "func main()",
        "port_parsing": "port := os.Args[1]",
        "server_setup": "http.ListenAndServe with http.HandleFunc",
        "response_format": "JSON with encoding/json"
    },
    "monitoring": {
        "process_pattern": "[^/]*$",
        "name_extraction": "cmdLine.Contains(\"{service_name}\") ? \"{service_name}\" :"
    }
}

# Add to the system
manager.add_language('go', go_config)
```

### 2. Generate Automation Script

```bash
# Generate the automation script
./languages/manager.py generate-script --language go --output add_go_cgi_app.sh

# Now you can use it
./languages/add_language_service.sh go my_api 8015 3
```

### 3. That's It! 🎉

The new language is now fully integrated with:
- ✅ YARP load balancing and routing
- ✅ Health monitoring and failover
- ✅ Admin dashboard integration
- ✅ Request logging and metrics
- ✅ Process monitoring
- ✅ Stress testing (auto-detected)
- ✅ Smoke testing for startup sanity checks

## 📁 File Structure

```
cgi-process-pool/
├── 🔧 Modular Language System
│   ├── languages.json              # Language definitions
│   ├── language_manager.py         # Core management engine
│   ├── add_language_service.sh     # Universal service generator
│   └── add_javascript_language.py  # Example: Adding new languages
├── 📜 Auto-Generated Scripts
│   ├── add_c_cgi_app.sh           # Generated C automation  
│   ├── add_python_cgi_app.sh      # Generated Python automation
│   ├── add_csharp_cgi_app.sh      # Generated C# automation
│   ├── add_javascript_cgi_app.sh  # Generated JS automation
│   └── add_rust_cgi_app.sh        # Generated Rust automation
└── 📋 Legacy Scripts (maintained for compatibility)
    ├── add_cgi_app.sh             # Original C script
    └── add_python_cgi_app.sh      # Original Python script
```

## 🎯 Benefits of Modular System

### Before (Hard-coded)
- ❌ Each language required manual script creation
- ❌ Duplicated code across automation scripts  
- ❌ Inconsistent patterns and implementations
- ❌ Hard to maintain and extend
- ❌ Adding new language = hours of work

### After (Modular)
- ✅ Single configuration file defines everything
- ✅ Shared automation template engine
- ✅ Consistent patterns across all languages
- ✅ Easy to maintain and extend
- ✅ Adding new language = 5 minutes of work

## 🔄 Migration Path

The system maintains **full backward compatibility**:

```bash
# These still work (legacy)
./add_cgi_app.sh myservice 8005 2
./add_python_cgi_app.sh myservice 8007 3

# But now you can also use (modern)
./add_language_service.sh c myservice 8005 2
./add_language_service.sh python myservice 8007 3
```

## 🛠️ Advanced Configuration

### Custom Health Checks
```json
{
  "runtime": {
    "health_check": "/?custom=health&token=abc123"
  }
}
```

### Build Requirements
```json
{
  "runtime": {
    "build_command": "gcc -O3 -flto -march=native -o {executable} {source_file}",
    "requirements": ["GCC 9+", "glibc-dev"]
  }
}
```

### Process Monitoring
```json
{
  "monitoring": {
    "process_pattern": "my_lang_runtime.*\\.ext",
    "name_extraction": "customExtraction(\"{service_name}\")"
  }
}
```

## 🧪 Testing New Languages

The stress test automatically detects and includes new languages:

```bash
# Stress test will automatically test all available languages
./stress_test.sh

# Including your newly added languages
# - JavaScript services at /api/my_js_service  
# - Rust services at /api/my_rust_service
# - etc.
```

## 📈 Future Enhancements

The modular system enables easy addition of:

- **More Languages**: PHP, Ruby, Kotlin, Swift, Dart, etc.
- **Custom Runtimes**: Docker containers, Lambda functions, etc.
- **Advanced Features**: Database connections, message queues, etc.
- **Service Templates**: Pre-built service patterns
- **IDE Integration**: VS Code extensions, language servers

## 🎉 Summary

The modular language system transforms language support from a manual, error-prone process into an automated, consistent, and extensible architecture. Adding a new language now takes minutes instead of hours, and all languages benefit from the same robust infrastructure and tooling.

**Before**: Hard-coded scripts for each language  
**After**: Data-driven, template-based language engine

This architectural change makes the CGI Process Pool a truly polyglot platform that can adapt to any development team's language preferences while maintaining consistency and reliability across all services.