# Adding New CGI Applications with YARP Integration

This guide shows you how to quickly add new CGI applications that automatically integrate with the YARP proxy system.

## 🚀 Quick Start - Automated Script

The easiest way to add a new CGI application is using the automated script:

```bash
./add_cgi_app.sh <app_name> <start_port> [instance_count]
```

### Examples:

```bash
# Add an "orders" service with 2 instances on ports 8005-8006
./add_cgi_app.sh orders 8005 2

# Add a "products" service with 3 instances on ports 8007-8009  
./add_cgi_app.sh products 8007 3

# Add a "notifications" service with 1 instance on port 8010
./add_cgi_app.sh notifications 8010 1
```

## 🔧 What the Script Does Automatically

The `add_cgi_app.sh` script performs all necessary integration steps:

### 1. **Creates CGI Source Code**
- Generates a complete C application with HTTP server
- Includes proper signal handling and threading
- Returns JSON responses with service metadata
- Handles query parameters and health checks

### 2. **Updates Build System**
- Adds new target to `Makefile`
- Creates build rule for the new service
- Compiles the service automatically

### 3. **Updates Pool Manager**
- Adds service configuration to `pool_manager.py`
- Configures ports and process limits
- Sets up health check endpoints

### 4. **Updates YARP Configuration**
- Adds route to `appsettings.json`
- Creates cluster with load balancing
- Configures health checks and multiple instances
- Updates endpoint list in `Program.cs`

### 5. **Updates Monitoring**
- Adds service detection to request logging
- Updates process monitoring regex patterns
- Ensures admin dashboard shows new service

### 6. **Builds and Tests**
- Compiles the new service
- Provides testing commands
- Shows next steps

## 📋 Generated CGI Service Features

Each generated CGI service includes:

### 🔌 **HTTP Server Capabilities**
- Multi-threaded request handling
- Graceful shutdown with signal handling
- Socket reuse and proper error handling
- JSON API responses

### 📊 **Standard Response Format**
```json
{
  "service": "orders",
  "query": "status=pending",
  "data": {
    "status": "success", 
    "message": "orders service is running"
  },
  "pid": 12345,
  "timestamp": 1757124567,
  "version": "1.0.0"
}
```

### 🏥 **Health Check Support**
- Built-in health check endpoint
- YARP-compatible health monitoring
- Process lifecycle management

## 🛠 Manual Customization

After running the script, you can customize your service:

### 1. **Modify Business Logic**
Edit the generated `<service>.c` file:

```c
void handle_orders_request(int client_socket, const char* query_string) {
    // Add your business logic here
    // Parse parameters, access databases, etc.
    
    char response[2048];
    snprintf(response, sizeof(response),
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: application/json\r\n"
        "\r\n"
        "{\"orders\": [{\"id\": 1, \"status\": \"pending\"}]}");
    
    send(client_socket, response, strlen(response), 0);
}
```

### 2. **Adjust Configuration**
Modify `pool_manager.py`:

```python
'orders': {
    'command': './orders.cgi',
    'ports': [8005, 8006],
    'min_processes': 2,      # Increase for high-traffic services
    'max_processes': 5,      # Set appropriate limits
    'health_check': '/?status=health'
}
```

### 3. **Custom YARP Routes**
Update `proxy/CGIProxy/appsettings.json`:

```json
"orders-route": {
  "ClusterId": "orders-cluster",
  "Match": {
    "Path": "/api/orders/{**catch-all}"
  },
  "Transforms": [
    { "PathRemovePrefix": "/api/orders" },
    { "RequestHeader": "X-Service", "Set": "orders" }  // Add custom headers
  ]
}
```

## 🧪 Testing Your New Service

After adding a service, test it thoroughly:

### 1. **Basic Functionality Test**
```bash
# Start the system
make run-pool  # Terminal 1
make run-yarp  # Terminal 2

# Test the service
curl "http://localhost:8080/api/orders?status=pending"
```

### 2. **Load Balancing Test**
```bash
# Make multiple requests to see different PIDs
for i in {1..4}; do
  curl -s "http://localhost:8080/api/orders?test=$i" | jq '.pid'
done
```

### 3. **Health Check Test**
```bash
# Direct health check
curl "http://localhost:8005/?status=health"

# YARP health monitoring
curl "http://localhost:8080/api/process/orders"
```

### 4. **Admin Dashboard**
- Visit: `http://localhost:8080/admin`
- Verify service appears in process monitoring
- Check metrics and request tracking

## 📈 Scaling Your Services

### Add More Instances
To add more instances to an existing service:

1. **Update pool_manager.py**:
```python
'orders': {
    'ports': [8005, 8006, 8011, 8012],  # Add more ports
    'max_processes': 4                   # Increase limit
}
```

2. **Update YARP appsettings.json**:
```json
"orders-cluster": {
  "Destinations": {
    "orders-1": {"Address": "http://127.0.0.1:8005/"},
    "orders-2": {"Address": "http://127.0.0.1:8006/"},
    "orders-3": {"Address": "http://127.0.0.1:8011/"},  // Add new
    "orders-4": {"Address": "http://127.0.0.1:8012/"}   // instances
  }
}
```

3. **Restart the system**

## 🔍 Troubleshooting

### Common Issues

1. **Port Already in Use**
```bash
# Check what's using the port
netstat -tuln | grep 8005

# Choose different ports
./add_cgi_app.sh orders 8020 2
```

2. **Service Not Appearing in Admin**
- Check YARP logs for routing errors
- Verify service name consistency across files
- Restart YARP proxy after configuration changes

3. **Health Check Failures**
- Test service directly on its port
- Check health check URL format
- Verify service is listening and responding

### Debug Commands
```bash
# Check running processes
ps aux | grep -E "(orders|products).cgi"

# Test service directly
curl -v "http://localhost:8005/?status=health"

# Check YARP routing
curl -v "http://localhost:8080/api/orders"

# View all metrics
curl "http://localhost:8080/api/metrics/summary" | jq
```

## 📚 Advanced Examples

### Database-Connected Service
```c
void handle_products_request(int client_socket, const char* query_string) {
    // Connect to database (SQLite, PostgreSQL, etc.)
    // Execute queries based on parameters
    // Return formatted JSON results
}
```

### Authenticated Service
```c
void handle_secure_request(int client_socket, const char* query_string) {
    // Extract Authorization header
    // Validate JWT token or API key
    // Return 401/403 for unauthorized requests
}
```

### WebSocket-Compatible Service
```c
void handle_websocket_upgrade(int client_socket) {
    // Handle WebSocket handshake
    // Upgrade connection protocol
    // Implement real-time communication
}
```

## 🎯 Best Practices

1. **Naming**: Use consistent, descriptive service names
2. **Ports**: Use sequential port ranges for organization
3. **Health Checks**: Always implement proper health endpoints  
4. **Error Handling**: Include comprehensive error responses
5. **Logging**: Add structured logging for debugging
6. **Security**: Validate all input parameters
7. **Performance**: Use connection pooling for databases
8. **Monitoring**: Include metrics and status endpoints

This automation makes it trivial to add new CGI applications while maintaining full integration with your YARP-based process pool architecture!