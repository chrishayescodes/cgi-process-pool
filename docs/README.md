# Documentation

Comprehensive documentation for the CGI Process Pool system, covering architecture, usage, and implementation details.

## 🎯 Purpose

This directory contains all project documentation, including architectural overviews, implementation guides, and usage instructions for the multi-language CGI Process Pool system.

## 📁 Structure

```
docs/
├── README.md                 # This file - documentation index
├── ARCHITECTURE.md           # System architecture and design  
├── MODULAR_LANGUAGES.md      # Language system architecture
├── ADDING_CGI_APPS.md        # Guide for adding new services
├── ADDING_NEW_POOLS.md       # Pool management documentation  
└── cgi_pool_poc.md           # Original proof-of-concept documentation
```

## 📚 Documentation Overview

### **ARCHITECTURE.md**
High-level system architecture and design principles:
- 🏗️ **System Components**: Pool Manager, YARP Proxy, Discovery System
- 🔄 **Data Flow**: Request routing, load balancing, health monitoring
- 🎯 **Design Patterns**: Modular architecture, service discovery, process management
- 🔌 **Integration Points**: Inter-component communication and dependencies

### **MODULAR_LANGUAGES.md** 
Comprehensive guide to the modular language system:
- 🔧 **Language Management**: Adding and configuring new programming languages
- 📝 **Configuration Format**: JSON-based language definitions
- 🚀 **Automation Scripts**: Template-based script generation
- 🔍 **Examples**: JavaScript/Node.js and Rust integration examples

### **ADDING_CGI_APPS.md**
Step-by-step guide for adding new services:
- 🛠️ **Service Creation**: Building new CGI applications
- 📋 **Registration Process**: Adding services to the discovery system
- 🔧 **Configuration**: Port assignment, health checks, load balancing
- 🧪 **Testing**: Validation and integration testing

### **ADDING_NEW_POOLS.md**
Pool management and scaling documentation:
- ⚖️ **Scaling Strategies**: Horizontal and vertical scaling approaches
- 📊 **Resource Management**: Memory, CPU, and connection management
- 🔍 **Monitoring**: Health checks, metrics, and alerting
- 🔧 **Configuration**: Pool sizing and performance tuning

### **cgi_pool_poc.md**
Original proof-of-concept documentation:
- 💡 **Initial Concept**: Original design goals and requirements
- 🧪 **Prototype**: Early implementation and lessons learned
- 📈 **Evolution**: How the system grew from POC to production-ready
- 📝 **Historical Context**: Development decisions and trade-offs

## 🎯 Key Concepts

### **Multi-Language Support**
The system supports multiple programming languages through a unified interface:
- **C**: High-performance compiled services
- **Python**: Scripted services with rich ecosystem support
- **C# Scripts**: .NET ecosystem with dotnet-script runtime
- **Extensible**: Easy addition of new languages via configuration

### **Service Discovery**
Automatic service detection and configuration:
- **Manifest-Based**: Centralized service registry in `manifest.json`
- **Dynamic Build Rules**: Automatic Makefile generation
- **Language-Agnostic**: Uniform handling across all supported languages
- **Zero-Config**: Services automatically integrated upon registration

### **Process Pool Management**
Robust service lifecycle management:
- **Health Monitoring**: Continuous service health verification
- **Automatic Restart**: Failed service recovery
- **Load Balancing**: Multi-instance service distribution
- **Resource Management**: Efficient resource utilization

### **YARP Integration**  
Production-ready reverse proxy with:
- **Load Balancing**: Round-robin request distribution
- **Health Checks**: Service availability monitoring
- **Admin Dashboard**: Real-time system monitoring
- **Configuration**: Dynamic route and cluster management

## 🚀 Getting Started

### **For Developers**
1. Read `ARCHITECTURE.md` for system overview
2. Follow `ADDING_CGI_APPS.md` to add your first service
3. Explore `MODULAR_LANGUAGES.md` for language extension
4. Reference `ADDING_NEW_POOLS.md` for scaling

### **For System Administrators**
1. Review `ARCHITECTURE.md` for deployment understanding
2. Study `ADDING_NEW_POOLS.md` for operational guidance
3. Understand service management via `ADDING_CGI_APPS.md`
4. Monitor system health using documented endpoints

### **For Language Implementers**
1. Study `MODULAR_LANGUAGES.md` for extension patterns
2. Review existing language implementations in `../languages/definitions.json`
3. Follow examples for JavaScript/Node.js and Rust integration
4. Test new languages using provided testing infrastructure

## 📖 Documentation Standards

### **Format Guidelines**
- **Markdown**: All documentation in GitHub-flavored Markdown
- **Structure**: Consistent heading hierarchy and navigation
- **Examples**: Concrete code examples with explanations
- **Commands**: Copy-paste ready command examples
- **Diagrams**: ASCII diagrams for system architecture where helpful

### **Content Standards**
- **Clarity**: Clear, concise explanations suitable for different skill levels
- **Completeness**: Comprehensive coverage of features and capabilities
- **Accuracy**: Up-to-date with current implementation
- **Examples**: Real-world usage patterns and common scenarios

## 🔗 Cross-References

### **Related Module Documentation**
- **Languages**: `../languages/README.md` - Language system implementation
- **Discovery**: `../discovery/README.md` - Service discovery details
- **Pool**: `../pool/README.md` - Process management implementation
- **Testing**: `../testing/README.md` - Testing infrastructure
- **Proxy**: `../proxy/CGIProxy/README.md` - YARP proxy configuration

### **External References**  
- **YARP Documentation**: Microsoft's YARP reverse proxy
- **dotnet-script**: C# scripting runtime documentation
- **Python CGI**: Python CGI development patterns
- **C HTTP Servers**: Low-level HTTP server implementation

## 🧭 Navigation Guide

### **Quick Reference**
```bash
# System architecture
cat docs/ARCHITECTURE.md

# Add a new service
cat docs/ADDING_CGI_APPS.md

# Add a new language
cat docs/MODULAR_LANGUAGES.md

# Scale the system  
cat docs/ADDING_NEW_POOLS.md
```

### **Implementation Flow**
1. **Understand Architecture** → `ARCHITECTURE.md`
2. **Add Your Service** → `ADDING_CGI_APPS.md`
3. **Test Integration** → `../testing/README.md`
4. **Scale if Needed** → `ADDING_NEW_POOLS.md`
5. **Add Languages** → `MODULAR_LANGUAGES.md`

The documentation provides comprehensive coverage of the CGI Process Pool system, enabling effective development, deployment, and maintenance across all supported languages and use cases.