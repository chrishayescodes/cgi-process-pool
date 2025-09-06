# Testing Module

Comprehensive testing infrastructure for the CGI Process Pool system, including smoke tests, stress tests, and multi-language service validation.

## 🎯 Purpose

This module provides automated testing, startup sanity checks, performance validation, and system health monitoring for the multi-language CGI Process Pool.

## 📁 Structure

```
testing/
├── README.md           # This file
├── smoketest.sh        # Startup sanity and endpoint testing
├── stress_test.sh      # Load testing and performance validation  
├── unit/               # Unit tests (placeholder)
├── integration/        # Integration tests (placeholder) 
└── fixtures/           # Test fixtures (placeholder)
```

## 🚀 Quick Start

### Smoke Tests (Startup Sanity)
```bash
# Basic smoke test
make smoke-test

# Verbose smoke test with detailed output
make smoke-test-verbose

# Custom smoke test options
./testing/smoketest.sh --proxy-url http://localhost:8080 --timeout 10 --verbose
```

### Stress Tests (Performance)
```bash
# Default stress test
./testing/stress_test.sh

# Custom load parameters
./testing/stress_test.sh -c 100 -t 500 -d 60  # 100 concurrent, 500 total, 60s duration

# Language-specific stress testing
./testing/stress_test.sh --language python
./testing/stress_test.sh --language csharp
```

### Unit Tests
```bash
# Run unit tests on built services
make test
```

## 🔧 Core Components

### **smoketest.sh** - Startup Sanity Testing
- **Service Discovery**: Auto-detects all services from `manifest.json`
- **Endpoint Validation**: Tests all API endpoints and health checks
- **System Integration**: Validates YARP proxy and admin dashboard
- **Dependency Checking**: Ensures pool manager services are running
- **Comprehensive Reporting**: Color-coded results with actionable recommendations

### **stress_test.sh** - Performance Validation  
- **Multi-Language Support**: Tests C, Python, and C# services simultaneously
- **Load Balancing Verification**: Confirms round-robin distribution across instances
- **Concurrent Load Testing**: Configurable concurrency and duration
- **Resource Monitoring**: Tracks CPU, memory, and connection usage
- **Automatic Detection**: Discovers services and ports from manifest
- **Graceful Degradation**: Handles service failures during testing

## 🔍 Smoke Test Features

### **Automatic Service Discovery**
```bash
# Tests discovered from manifest.json:
- search API endpoints and health checks
- auth API endpoints and health checks  
- python_cgi API endpoints and examples
- csharp_script API endpoints and examples
```

### **System Component Testing**
- **Main Endpoints**: Root (`/`), Admin (`/admin`), Admin API (`/admin-api/health`)
- **Service APIs**: All discovered service endpoints from manifest
- **Health Checks**: Language-specific health verification endpoints
- **Example Requests**: Tests actual usage examples from service documentation
- **Direct Service Ports**: Bypasses proxy to test services directly

### **Test Categories**
1. **Dependencies**: Verify pool manager services are running
2. **Main System**: Test core system endpoints  
3. **Service APIs**: Test all discovered service endpoints
4. **Health Checks**: Validate service health monitoring
5. **Examples**: Test documented usage patterns
6. **Direct Access**: Test services without proxy layer

## 🔋 Stress Test Features

### **Multi-Language Load Testing**
- **C Services**: High-performance compiled service testing
- **Python Services**: Interpreter-based service validation  
- **C# Scripts**: dotnet-script runtime performance testing
- **Mixed Workloads**: Simultaneous multi-language stress testing

### **Load Balancing Validation**
- **Round-Robin Verification**: Confirms requests distribute across instances
- **Instance Health**: Validates all service instances respond correctly
- **Failover Testing**: Tests behavior when instances become unavailable
- **Port Distribution**: Verifies load spreads across configured ports

### **Performance Metrics**
- **Response Times**: Average, min, max response times per service
- **Throughput**: Requests per second across all services
- **Success Rate**: Percentage of successful requests
- **Error Analysis**: Categorization of failed requests
- **Resource Usage**: CPU and memory consumption during load

## 📊 Test Output and Reporting

### **Smoke Test Output**
```
🔍 CGI Process Pool Smoke Test Suite
=====================================

✅ Pool Manager Services (0.123s)
✅ Root Endpoint (0.045s)
✅ Admin Dashboard (0.067s)
✅ search API (0.089s)
✅ search Health Check (0.034s)
❌ python_cgi API - Expected status 200, got 503

====================
SMOKE TEST SUMMARY
====================

✅ 14 out of 16 tests passed!
System Status: ✅ System appears to be healthy
```

### **Stress Test Output**
```
🚀 Multi-Language CGI Stress Test
================================

Services detected: search, auth, python_cgi, csharp_script
Load configuration: 50 concurrent, 1000 total requests, 30s duration

Testing search (C) on ports 8000,8001...
Testing python_cgi (Python) on port 8003...
Testing csharp_script (C#) on port 8004...

Results:
- search: 334.2 req/s, 99.8% success, 0.149s avg
- python_cgi: 127.8 req/s, 100% success, 0.389s avg  
- csharp_script: 89.4 req/s, 100% success, 0.562s avg
```

## 🔧 Configuration and Customization

### **Smoke Test Options**
```bash
./testing/smoketest.sh [options]

Options:
  --proxy-url URL    Proxy URL (default: http://localhost:8080)
  --timeout SEC      Request timeout in seconds (default: 5)
  --verbose          Enable detailed output
  --help             Show help message
```

### **Stress Test Options**
```bash
./testing/stress_test.sh [options]

Options:
  -c, --concurrent NUM    Concurrent connections (default: 50)
  -t, --total NUM         Total requests (default: 1000)  
  -d, --duration SEC      Test duration (default: 30)
  --language LANG         Test specific language only
  --url URL               Custom base URL
  --detailed              Show detailed per-request results
```

## 🧪 Integration Testing

### **Build System Integration**
```bash
# Makefile targets
make test              # Unit tests on built services
make smoke-test        # Startup sanity checks
make smoke-test-verbose # Detailed smoke testing
```

### **Service Discovery Integration**
- Reads `../discovery/manifest.json` for service definitions
- Auto-detects API endpoints, health checks, and examples
- Supports multi-language service testing
- Handles service-specific test parameters

### **Pool Manager Integration**  
- Verifies pool manager service availability
- Tests direct service ports and proxy routes
- Validates health check endpoints used by pool manager
- Confirms load balancing across multiple instances

## 🔍 Test Development

### **Adding New Test Cases**
1. **Smoke Tests**: Add service definitions to `manifest.json`
2. **Stress Tests**: Services auto-detected from discovery system
3. **Unit Tests**: Add service-specific tests to `unit/` directory
4. **Integration Tests**: Add system-level tests to `integration/`

### **Custom Test Fixtures**
```bash
# Add test data to fixtures/
testing/fixtures/
├── sample_requests.json    # Test request patterns
├── expected_responses/     # Expected response templates
└── test_data/             # Test input data
```

## 📈 Performance Benchmarking

### **Baseline Performance**
- **C Services**: ~300-400 req/s per instance
- **Python Services**: ~100-150 req/s per instance  
- **C# Scripts**: ~80-120 req/s per instance
- **Load Balancing**: Linear scaling with additional instances

### **Resource Usage**
- **Memory**: Baseline ~10-50MB per service instance
- **CPU**: Load scales with request volume and complexity
- **Connections**: Efficient connection handling across all languages

## 🔗 Integration Points

### **Discovery System** (`../discovery/`)
- Service endpoint detection
- Health check configuration
- Example request patterns
- Multi-language service support

### **Pool Manager** (`../pool/`)
- Service availability verification
- Health monitoring validation
- Process lifecycle testing  
- Load balancing confirmation

### **YARP Proxy** (`../proxy/`)
- Endpoint routing verification
- Load balancing validation
- Admin dashboard testing
- Service integration confirmation

The testing module ensures system reliability, performance validation, and comprehensive coverage across all supported languages and service types.