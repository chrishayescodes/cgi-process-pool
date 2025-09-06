# CGI Process Pool - Operations Management

This directory contains the hardened process lifecycle management system for the CGI Process Pool, designed to solve process management issues and provide robust startup/shutdown capabilities.

## Problem Solved

**Before:** Manual process management led to:
- Orphaned processes from failed startups
- Difficult cleanup when processes got stuck
- No unified way to start/stop the entire system
- Process tracking gaps and conflicts

**After:** Unified process lifecycle management with:
- Automatic orphaned process cleanup
- Graceful shutdown with fallback to force termination
- Dependency-aware startup ordering
- Health checking and monitoring
- Process registry and tracking

## Core Components

### `process_manager.py`
The main process lifecycle manager providing:
- **Process Registry**: Tracks all managed processes
- **Dependency Management**: Starts processes in correct order
- **Health Checking**: Monitors process health via port/HTTP/command checks
- **Graceful Shutdown**: SIGTERM → wait → SIGKILL fallback
- **Orphan Cleanup**: Finds and terminates abandoned processes
- **Signal Handling**: Responds to Ctrl+C and system shutdown signals

### `startup.sh` 
Unified startup script with:
- **Pre-flight Checks**: Validates dependencies and configuration
- **Build Integration**: Optionally rebuilds services before start
- **Cleanup Option**: Removes orphaned processes before start
- **Monitoring Mode**: Can run with or without process monitoring
- **Environment Variables**: Configurable via env vars

### `shutdown.sh`
Graceful shutdown script with:
- **Managed Shutdown**: Stops processes via process manager
- **Force Options**: Can force-kill stubborn processes
- **Comprehensive Cleanup**: Removes orphaned processes and temp files
- **Verification**: Confirms all processes stopped

### `process_config.json`
Process configuration defining:
- **Command Definition**: How to start each process
- **Dependencies**: Which processes depend on others
- **Health Checks**: How to verify process health
- **Restart Policies**: When to restart failed processes
- **Timing**: Startup delays and timeouts

## Usage

### Quick Start
```bash
# Start the complete system
make start

# Check status
make status  

# Stop the system
make stop
```

### Available Commands

#### Makefile Integration
```bash
make start         # Start complete system with monitoring
make start-bg      # Start system in background (no monitoring)
make stop          # Graceful shutdown
make stop-force    # Force shutdown (kills stuck processes)
make restart       # Stop + Start
make status        # Show process status
make cleanup       # Clean up orphaned processes only
```

#### Direct Script Usage
```bash
# Startup options
./ops/startup.sh --build --cleanup --monitor
./ops/startup.sh --no-build --no-monitor

# Shutdown options  
./ops/shutdown.sh --force --cleanup

# Process manager direct usage
python3 ops/process_manager.py start
python3 ops/process_manager.py stop
python3 ops/process_manager.py status
python3 ops/process_manager.py cleanup
```

## Configuration

### Process Definition
Each process in `process_config.json` supports:

```json
{
  "processes": {
    "service_name": {
      "command": ["executable", "arg1", "arg2"],
      "cwd": "working/directory",
      "env": {"ENV_VAR": "value"},
      "restart_policy": "always|on-failure|no",
      "startup_delay": 5,
      "depends_on": ["other_service"],
      "health_check": {
        "type": "port|http|command", 
        "target": "8000|http://localhost:8080/health|./check.sh",
        "timeout": 10
      }
    }
  }
}
```

### Health Check Types
- **port**: Check if TCP port is listening
- **http**: HTTP GET request expecting 200 response  
- **command**: Execute shell command expecting exit code 0

### Restart Policies
- **always**: Restart if process dies or health check fails
- **on-failure**: Restart only if process dies unexpectedly
- **no**: Don't restart, just remove from registry

## Features

### Dependency Management
Processes start in dependency order. If `yarp_proxy` depends on `pool_manager`, the pool manager starts first and must pass health checks before the proxy starts.

### Graceful Shutdown
1. Send SIGTERM to process groups
2. Wait for graceful shutdown (configurable timeout)
3. Send SIGKILL if processes don't respond
4. Clean up process registry

### Orphan Detection
Automatically detects and cleans up processes matching patterns:
- `*.cgi` executables
- `sample_*_cgi.py` Python services  
- `dotnet-script *.csx` C# scripts
- `pool/manager.py` pool manager instances
- `dotnet run *8080` proxy instances

### Signal Handling
Responds to:
- **SIGINT** (Ctrl+C): Graceful shutdown
- **SIGTERM**: System shutdown request
- **Exit hooks**: Cleanup on abnormal termination

## Environment Variables

```bash
# Configuration file location
export CGI_POOL_CONFIG="ops/custom_config.json"

# Build services on startup
export CGI_POOL_BUILD=true

# Clean orphans on startup  
export CGI_POOL_CLEANUP=true

# Force shutdown behavior
export CGI_POOL_FORCE=false
```

## Troubleshooting

### Common Issues

**Process won't start**: Check health check configuration, increase startup_delay
**Health check fails**: Verify the service is actually listening on expected port/endpoint  
**Orphaned processes**: Run `make cleanup` or `make stop-force`
**Stuck shutdown**: Use `make stop-force` to kill stubborn processes

### Debug Commands
```bash
# Verbose process status
python3 ops/process_manager.py status

# Manual cleanup
python3 ops/process_manager.py cleanup

# Check what processes are running
ps aux | grep -E "(\.cgi|sample.*cgi|pool/manager|dotnet.*8080)"

# Force kill specific pattern
pkill -f "pattern"
```

## Integration with Existing System

The ops system integrates with existing components:
- **Makefile**: New lifecycle commands added to main Makefile
- **Pool Manager**: `pool/manager.py` started as managed process
- **YARP Proxy**: `proxy/CGIProxy` started with dependency on pool manager  
- **Discovery System**: Build integration via `make all`
- **Testing**: Can be started in background for automated tests

## Benefits

1. **No More Manual Process Management**: Single command starts entire system
2. **No More Orphaned Processes**: Automatic cleanup on start/stop
3. **Robust Startup**: Dependency ordering and health checking
4. **Graceful Shutdown**: Proper termination with fallback force-kill
5. **Process Monitoring**: Optional continuous health monitoring  
6. **CI/CD Ready**: Background mode for automated testing
7. **Development Friendly**: Easy restart and status checking

This hardened process management system eliminates the manual process wrangling and provides a production-ready lifecycle management solution.