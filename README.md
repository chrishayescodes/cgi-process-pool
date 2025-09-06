# CGI Process Pool - Proof of Concept

A modern implementation of CGI-style process isolation with pooling for performance, demonstrating how to combine classic CGI architecture with modern tooling.

## Architecture

```
[nginx] → [Pool Manager] → [CGI Process Pool]
   ↓           ↓              ↓
HTTP        Process        HTTP Server
Router      Spawner        (search.cgi/auth.cgi)
```

## Features

- **Process Isolation**: Each CGI process runs independently
- **Dynamic Pooling**: Automatic scaling between min/max processes
- **Health Monitoring**: Continuous health checks with automatic recovery
- **Load Balancing**: nginx distributes requests across healthy processes
- **Language Agnostic**: CGI processes can be written in any language
- **Fault Tolerance**: Individual process crashes don't affect the system

## Quick Start

### Prerequisites

- GCC compiler
- Python 3.6+
- nginx
- make

### Installation

1. Install Python dependencies:
```bash
make install-deps
```

2. Build the CGI executables:
```bash
make all
```

### Running the Demo

The easiest way to see everything in action:

```bash
make run-demo
```

This will:
1. Build the CGI executables
2. Start the pool manager
3. Configure and start nginx
4. Run test requests
5. Demonstrate load balancing

### Manual Operation

1. Start just the pool manager:
```bash
make run-pool
```

2. In another terminal, configure and start nginx:
```bash
sudo nginx -c $(pwd)/nginx.conf
```

3. Test the endpoints:
```bash
# Search API
curl "http://localhost/api/search?q=test"

# Auth API  
curl "http://localhost/api/auth?user=john"

# Pool status
curl "http://localhost/pool-status"
```

## Project Structure

```
.
├── search.c          # Search CGI service (C)
├── auth.c            # Auth CGI service (C)
├── pool_manager.py   # Process pool manager (Python)
├── nginx.conf        # nginx configuration
├── demo.sh           # Demo script
├── Makefile          # Build automation
└── README.md         # This file
```

## How It Works

1. **CGI Processes**: Simple HTTP servers written in C that handle one request at a time
2. **Pool Manager**: Python script that:
   - Spawns CGI processes on different ports
   - Monitors process health
   - Maintains min/max process counts
   - Generates nginx upstream configuration
3. **nginx**: Routes incoming requests to healthy CGI processes using upstream pools

## Configuration

### Pool Manager Settings

Edit `pool_manager.py` to adjust:
- `min_processes`: Minimum processes per pool (default: 2)
- `max_processes`: Maximum processes per pool (default: 5)
- Health check interval (default: 5 seconds)

### Adding New CGI Services

1. Create your CGI executable (any language)
2. Add to `pool_manager.py`:
```python
manager.add_pool('service_name', './service.cgi', min_processes=2, max_processes=5)
```
3. Add nginx location block in `nginx.conf`

## Testing

Run basic tests:
```bash
make test
```

## Monitoring

The pool manager outputs status information:
- Process spawning/termination
- Health check results
- Port assignments

Check `/tmp/cgi_upstreams.conf` to see the generated nginx upstream configuration.

## Cleanup

Stop all services:
```bash
# If using demo.sh, just press Ctrl+C

# Or manually:
pkill -f pool_manager.py
sudo nginx -s stop
make clean
```

## Benefits Demonstrated

1. **Process Isolation**: Each request can be handled by a separate process
2. **Language Flexibility**: Mix C, Python, Go, Rust, etc.
3. **Simple Deployment**: No application servers or frameworks required
4. **Standard Tools**: Uses nginx, systemd, Docker (all standard ops tools)
5. **Fault Tolerance**: Process crashes don't bring down the service
6. **Dynamic Scaling**: Adjust process count based on load

## Next Steps for Production

- Add proper HTTP/1.1 support to CGI processes
- Implement request/response streaming
- Add metrics collection (Prometheus)
- Use Unix domain sockets for better performance
- Container deployment with Docker Compose
- systemd service files for process management
- TLS termination at nginx
- Rate limiting and DDoS protection
- Distributed tracing support

## License

This is a proof of concept for demonstration purposes.