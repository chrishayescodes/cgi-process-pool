# Proposed Higher-Level Organization

## 🎯 Current Issues
- Language-related files scattered in root
- Build/discovery systems mixed with everything else
- Testing infrastructure not clearly separated
- Pool management mixed with other concerns
- Hard to understand the system's architecture at a glance

## 🏗️ Proposed Structure

### **Top-Level Organization by Concerns**

```
cgi-process-pool/
├── 📄 README.md                    # Main project documentation
├── 📄 Makefile                     # Top-level build interface
│
├── 🔷 languages/                   # Language Support System
│   ├── definitions.json            # Language configurations (renamed from languages.json)
│   ├── manager.py                  # Language management engine (renamed from language_manager.py)
│   ├── add_service.sh              # Universal service generator (renamed from add_language_service.sh)
│   ├── generators/                 # Auto-generated scripts
│   │   ├── add_c_service.sh
│   │   ├── add_python_service.sh
│   │   ├── add_csharp_service.sh
│   │   ├── add_javascript_service.sh
│   │   └── add_rust_service.sh
│   └── examples/                   # Language addition examples
│       └── add_new_languages.py    # Demo: adding JS & Rust
│
├── 🔍 discovery/                   # Service Discovery System
│   ├── discovery.py                # Main discovery engine
│   ├── manifest.json               # Service registry (moved from root)
│   └── samples/                    # Sample applications (renamed from .samples)
│       ├── c/
│       ├── python/
│       ├── csharp/
│       └── templates/
│
├── 🏊 pool/                        # Process Pool Management
│   ├── manager.py                  # Pool manager (renamed from pool_manager.py)
│   ├── config/                     # Pool configurations
│   └── monitoring/                 # Process monitoring utilities
│
├── 🧪 testing/                     # Testing Infrastructure
│   ├── stress_test.sh              # Comprehensive load testing
│   ├── unit/                       # Unit tests
│   ├── integration/                # Integration tests
│   └── fixtures/                   # Test fixtures and data
│
├── 🔧 build/                       # Build System & Setup
│   ├── check_dependencies.sh       # Dependency checking
│   ├── setup/                      # Setup scripts
│   ├── artifacts/                  # Compiled outputs (gitignored)
│   └── rules/                      # Generated build rules
│
├── 🌐 proxy/                       # YARP Reverse Proxy (existing)
│   └── CGIProxy/                   # .NET YARP application
│
├── 📚 docs/                        # Documentation (renamed from .docs)
│   ├── ARCHITECTURE.md
│   ├── MODULAR_LANGUAGES.md
│   ├── ADDING_CGI_APPS.md
│   ├── ADDING_NEW_POOLS.md
│   └── cgi_pool_poc.md
│
└── 🗂️ legacy/                      # Legacy Scripts (compatibility)
    ├── add_cgi_app.sh              # Original C script
    ├── add_python_cgi_app.sh       # Original Python script
    └── demo.sh                     # Legacy demo
```

## 🎯 Benefits of This Organization

### **Clear Separation of Concerns**
- **Languages**: Everything related to language support in one place
- **Discovery**: Service registration and sample management
- **Pool**: Process lifecycle and management
- **Testing**: All testing infrastructure together
- **Build**: Build system, dependencies, and artifacts
- **Docs**: Clean documentation organization

### **Better Developer Experience**
- Easy to find language-related functionality
- Clear testing infrastructure
- Build system is self-contained
- Documentation is organized and accessible

### **Maintainability**
- Each subsystem is independent
- Clear ownership and responsibility
- Easier to extend and modify
- Better for team collaboration

### **User Experience**
- Top-level Makefile provides simple interface
- `languages/add_service.sh` is the main entry point
- Documentation is easy to navigate
- Legacy scripts maintain compatibility

## 🚀 Migration Strategy

### **Phase 1: Create Structure** ✅
Create new directory structure with organized folders

### **Phase 2: Move Files** 
Move files to their appropriate locations:
- Language files → `languages/`
- Discovery files → `discovery/`
- Pool files → `pool/`
- Testing files → `testing/`
- Build files → `build/`

### **Phase 3: Update References**
Update all file references, imports, and documentation

### **Phase 4: Maintain Compatibility**
Keep legacy scripts working with symlinks or wrappers

### **Phase 5: Update Documentation**
Update all documentation to reflect new structure

## 🔄 Backward Compatibility

To maintain compatibility during transition:
- Top-level symlinks for commonly used files
- Legacy folder with original scripts
- Makefile provides unified interface
- Gradual migration path for users

## 📋 Implementation Priority

1. **High Impact, Low Risk**: Documentation organization
2. **Medium Impact, Medium Risk**: Language system organization  
3. **High Impact, Medium Risk**: Discovery system organization
4. **Medium Impact, Low Risk**: Testing organization
5. **Medium Impact, High Risk**: Pool system organization (has many dependencies)

This organization transforms the project from a collection of scripts into a well-architected system with clear concerns and responsibilities.