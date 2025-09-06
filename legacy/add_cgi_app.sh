#!/bin/bash

# Script to add a new CGI application with full YARP integration
# Usage: ./add_cgi_app.sh <app_name> <start_port> [instance_count]

set -e

APP_NAME="$1"
START_PORT="$2"
INSTANCE_COUNT="${3:-2}"

if [ -z "$APP_NAME" ] || [ -z "$START_PORT" ]; then
    echo "Usage: $0 <app_name> <start_port> [instance_count]"
    echo "Example: $0 orders 8005 2"
    exit 1
fi

echo "🚀 Adding CGI application: $APP_NAME"
echo "📡 Start port: $START_PORT"
echo "🔢 Instances: $INSTANCE_COUNT"

# 1. Create CGI application source
echo "📝 Creating CGI source file..."
cat > "${APP_NAME}.c" << EOF
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <pthread.h>
#include <time.h>
#include <signal.h>

void handle_${APP_NAME}_request(int client_socket, const char* query_string) {
    char param_buffer[256] = {0};
    if (query_string) {
        strncpy(param_buffer, query_string, sizeof(param_buffer) - 1);
    }
    
    char response[2048];
    time_t now = time(NULL);
    
    snprintf(response, sizeof(response),
        "HTTP/1.1 200 OK\\r\\n"
        "Content-Type: application/json\\r\\n"
        "Access-Control-Allow-Origin: *\\r\\n"
        "Cache-Control: no-cache\\r\\n"
        "\\r\\n"
        "{"
        "\\"service\\": \\"${APP_NAME}\\", "
        "\\"query\\": \\"%s\\", "
        "\\"data\\": {\\"status\\": \\"success\\", \\"message\\": \\"${APP_NAME} service is running\\"}, "
        "\\"pid\\": %d, "
        "\\"timestamp\\": %ld, "
        "\\"version\\": \\"1.0.0\\""
        "}",
        param_buffer,
        getpid(),
        now
    );
    
    send(client_socket, response, strlen(response), 0);
}

void handle_request(int client_socket) {
    char buffer[1024];
    int bytes_received = recv(client_socket, buffer, sizeof(buffer) - 1, 0);
    
    if (bytes_received <= 0) {
        close(client_socket);
        return;
    }
    
    buffer[bytes_received] = '\\0';
    
    char *query_start = strstr(buffer, "GET /?");
    char *query_string = NULL;
    
    if (query_start) {
        query_start += 6;
        char *query_end = strstr(query_start, " HTTP");
        if (query_end) {
            *query_end = '\\0';
            query_string = query_start;
        }
    }
    
    handle_${APP_NAME}_request(client_socket, query_string);
    close(client_socket);
}

void* client_handler(void* arg) {
    int client_socket = *(int*)arg;
    free(arg);
    handle_request(client_socket);
    return NULL;
}

volatile int running = 1;
void signal_handler(int sig) {
    running = 0;
    printf("\\n${APP_NAME} service shutting down...\\n");
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\\n", argv[0]);
        exit(1);
    }
    
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    int port = atoi(argv[1]);
    int server_socket = socket(AF_INET, SOCK_STREAM, 0);
    
    if (server_socket < 0) {
        perror("Socket creation failed");
        exit(1);
    }
    
    int opt = 1;
    setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in server_addr = {0};
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(port);
    
    if (bind(server_socket, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        perror("Bind failed");
        exit(1);
    }
    
    if (listen(server_socket, 10) < 0) {
        perror("Listen failed");
        exit(1);
    }
    
    printf("${APP_NAME} service started on port %d (PID: %d)\\n", port, getpid());
    fflush(stdout);
    
    while (running) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        int client_socket = accept(server_socket, (struct sockaddr*)&client_addr, &client_len);
        
        if (client_socket < 0) {
            if (running) perror("Accept failed");
            continue;
        }
        
        int* client_ptr = malloc(sizeof(int));
        if (client_ptr) {
            *client_ptr = client_socket;
            
            pthread_t thread;
            if (pthread_create(&thread, NULL, client_handler, client_ptr) == 0) {
                pthread_detach(thread);
            } else {
                free(client_ptr);
                close(client_socket);
            }
        } else {
            close(client_socket);
        }
    }
    
    close(server_socket);
    printf("${APP_NAME} service stopped.\\n");
    return 0;
}
EOF

# 2. Update Makefile
echo "🔧 Updating Makefile..."
# Add to TARGETS
sed -i "s/^TARGETS = .*/& ${APP_NAME}.cgi/" Makefile

# Add build rule
cat >> Makefile << EOF

${APP_NAME}.cgi: ${APP_NAME}.c
	\$(CC) \$(CFLAGS) -o \$@ \$<
	@echo "✓ Built ${APP_NAME}.cgi"
EOF

# 3. Update pool_manager.py
echo "🐍 Updating pool_manager.py..."
# Generate port list
PORTS=""
for ((i=0; i<INSTANCE_COUNT; i++)); do
    PORT=$((START_PORT + i))
    if [ $i -eq 0 ]; then
        PORTS="[$PORT"
    else
        PORTS="${PORTS}, $PORT"
    fi
done
PORTS="${PORTS}]"

# Add to pools dictionary (before the closing brace)
sed -i "/^}/i\\
    '${APP_NAME}': {\\
        'command': './${APP_NAME}.cgi',\\
        'ports': ${PORTS},\\
        'min_processes': 1,\\
        'max_processes': ${INSTANCE_COUNT},\\
        'health_check': '/?status=health'\\
    }," pool_manager.py

# 4. Update YARP appsettings.json
echo "⚙️ Updating YARP configuration..."

# Create destinations JSON
DESTINATIONS=""
for ((i=0; i<INSTANCE_COUNT; i++)); do
    PORT=$((START_PORT + i))
    DEST_NAME="${APP_NAME}-$((i+1))"
    if [ $i -eq 0 ]; then
        DESTINATIONS="\"$DEST_NAME\": {\"Address\": \"http://127.0.0.1:$PORT/\"}"
    else
        DESTINATIONS="${DESTINATIONS}, \"$DEST_NAME\": {\"Address\": \"http://127.0.0.1:$PORT/\"}"
    fi
done

# Add route (before admin-route)
ROUTE_JSON="\"${APP_NAME}-route\": {
        \"ClusterId\": \"${APP_NAME}-cluster\",
        \"Match\": {
          \"Path\": \"/api/${APP_NAME}/{**catch-all}\"
        },
        \"Transforms\": [
          { \"PathRemovePrefix\": \"/api/${APP_NAME}\" }
        ],
        \"Metadata\": {
          \"Service\": \"${APP_NAME}\"
        }
      },"

# Add cluster (before admin-cluster)
CLUSTER_JSON="\"${APP_NAME}-cluster\": {
        \"LoadBalancingPolicy\": \"RoundRobin\",
        \"HealthCheck\": {
          \"Active\": {
            \"Enabled\": true,
            \"Interval\": \"00:00:10\",
            \"Timeout\": \"00:00:05\",
            \"Policy\": \"ConsecutiveFailures\",
            \"Path\": \"/?status=health\"
          }
        },
        \"Destinations\": {
          ${DESTINATIONS}
        }
      },"

# Insert route
sed -i "/\"admin-route\":/i\\${ROUTE_JSON}" proxy/CGIProxy/appsettings.json

# Insert cluster  
sed -i "/\"admin-cluster\":/i\\${CLUSTER_JSON}" proxy/CGIProxy/appsettings.json

# 5. Update YARP Program.cs endpoints
echo "🔌 Updating YARP endpoints..."
sed -i "s|/api/auth\" }|/api/auth\", \"/api/${APP_NAME}\" }|" proxy/CGIProxy/Program.cs

# 6. Update RequestLoggingMiddleware.cs
echo "📊 Updating request logging middleware..."
# Add service detection
NEW_SERVICE_CHECK="else if (context.Request.Path.StartsWithSegments(\"/api/${APP_NAME}\"))
            {
                requestMetric.Service = \"${APP_NAME}\";
            }"

sed -i "/else if (context.Request.Path.StartsWithSegments(\"/admin\"))/i\\            ${NEW_SERVICE_CHECK}" proxy/CGIProxy/Middleware/RequestLoggingMiddleware.cs

# 7. Update ProcessMonitorService.cs  
echo "🔍 Updating process monitoring..."
# Update regex pattern
sed -i "s|(search\\\\|auth)|(search\\\\|auth\\\\|${APP_NAME})|" proxy/CGIProxy/Services/ProcessMonitorService.cs

# Update name detection
sed -i "s|cmdLine.Contains(\"auth.cgi\") ? \"auth\" :|cmdLine.Contains(\"auth.cgi\") ? \"auth\" : cmdLine.Contains(\"${APP_NAME}.cgi\") ? \"${APP_NAME}\" :|" proxy/CGIProxy/Services/ProcessMonitorService.cs

# 8. Build the new service
echo "🔨 Building new service..."
make "${APP_NAME}.cgi"

echo ""
echo "✅ Successfully added ${APP_NAME} service!"
echo ""
echo "🚀 To start the system with your new service:"
echo "   1. Terminal 1: make run-pool"
echo "   2. Terminal 2: make run-yarp"
echo ""
echo "🧪 To test the new service:"
echo "   curl \"http://localhost:8080/api/${APP_NAME}?test=hello\""
echo ""
echo "📊 Monitor at: http://localhost:8080/admin"
echo ""