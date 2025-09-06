#!/usr/bin/env gcc -x c -o calculator -pthread -O2 && exec ./calculator
/*
 * Calculator CGI Service - Tutorial Example
 * 
 * A simple HTTP server that performs basic math operations
 * Demonstrates: HTTP parsing, JSON responses, query parameters
 * 
 * Usage: ./calculator <port>
 * Example: curl "http://localhost:8005/?op=add&a=5&b=3"
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <pthread.h>
#include <time.h>

#define BUFFER_SIZE 1024
#define RESPONSE_SIZE 2048

typedef struct {
    int client_socket;
    int server_port;
} client_info_t;

// Parse query parameter value from URL
char* get_query_param(const char* query, const char* param) {
    char* param_pos = strstr(query, param);
    if (!param_pos) return NULL;
    
    // Move past "param="
    param_pos += strlen(param) + 1;
    
    // Find end of value (& or end of string)
    char* end_pos = strchr(param_pos, '&');
    int value_len = end_pos ? (end_pos - param_pos) : strlen(param_pos);
    
    // Allocate and copy value
    char* value = malloc(value_len + 1);
    strncpy(value, param_pos, value_len);
    value[value_len] = '\0';
    
    return value;
}

// Perform the requested calculation
double calculate(const char* operation, double a, double b, int* valid) {
    *valid = 1;
    
    if (strcmp(operation, "add") == 0) {
        return a + b;
    } else if (strcmp(operation, "subtract") == 0) {
        return a - b;
    } else if (strcmp(operation, "multiply") == 0) {
        return a * b;
    } else if (strcmp(operation, "divide") == 0) {
        if (b == 0) {
            *valid = 0; // Division by zero
            return 0;
        }
        return a / b;
    } else {
        *valid = 0; // Unknown operation
        return 0;
    }
}

// Handle individual HTTP request
void* handle_request(void* arg) {
    client_info_t* client = (client_info_t*)arg;
    char buffer[BUFFER_SIZE];
    char response[RESPONSE_SIZE];
    
    // Read HTTP request
    int bytes_read = recv(client->client_socket, buffer, BUFFER_SIZE - 1, 0);
    if (bytes_read <= 0) {
        close(client->client_socket);
        free(client);
        return NULL;
    }
    buffer[bytes_read] = '\0';
    
    // Parse request line: "GET /?op=add&a=5&b=3 HTTP/1.1"
    char method[16], path[256], version[16];
    sscanf(buffer, "%s %s %s", method, path, version);
    
    // Extract query string (after ?)
    char* query = strchr(path, '?');
    if (!query) {
        // No query parameters - show help
        snprintf(response, RESPONSE_SIZE,
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: application/json\r\n"
            "Access-Control-Allow-Origin: *\r\n"
            "\r\n"
            "{"
            "\"service\": \"calculator\", "
            "\"pid\": %d, "
            "\"port\": %d, "
            "\"usage\": \"/?op=add&a=5&b=3\", "
            "\"operations\": [\"add\", \"subtract\", \"multiply\", \"divide\"], "
            "\"example\": \"curl 'http://localhost:%d/?op=add&a=10&b=5'\""
            "}",
            getpid(), client->server_port, client->server_port);
    } else {
        query++; // Skip the '?'
        
        // Extract parameters
        char* operation = get_query_param(query, "op");
        char* a_str = get_query_param(query, "a");
        char* b_str = get_query_param(query, "b");
        
        if (operation && a_str && b_str) {
            double a = atof(a_str);
            double b = atof(b_str);
            int valid = 1;
            double result = calculate(operation, a, b, &valid);
            
            if (valid) {
                // Successful calculation
                snprintf(response, RESPONSE_SIZE,
                    "HTTP/1.1 200 OK\r\n"
                    "Content-Type: application/json\r\n"
                    "Access-Control-Allow-Origin: *\r\n"
                    "\r\n"
                    "{"
                    "\"operation\": \"%s\", "
                    "\"a\": %.2f, "
                    "\"b\": %.2f, "
                    "\"result\": %.2f, "
                    "\"pid\": %d, "
                    "\"port\": %d, "
                    "\"timestamp\": %ld"
                    "}",
                    operation, a, b, result, getpid(), client->server_port, time(NULL));
            } else {
                // Invalid operation or division by zero
                snprintf(response, RESPONSE_SIZE,
                    "HTTP/1.1 400 Bad Request\r\n"
                    "Content-Type: application/json\r\n"
                    "Access-Control-Allow-Origin: *\r\n"
                    "\r\n"
                    "{"
                    "\"error\": \"Invalid operation or division by zero\", "
                    "\"operation\": \"%s\", "
                    "\"a\": %.2f, "
                    "\"b\": %.2f, "
                    "\"pid\": %d"
                    "}",
                    operation, a, b, getpid());
            }
        } else {
            // Missing parameters
            snprintf(response, RESPONSE_SIZE,
                "HTTP/1.1 400 Bad Request\r\n"
                "Content-Type: application/json\r\n"
                "Access-Control-Allow-Origin: *\r\n"
                "\r\n"
                "{"
                "\"error\": \"Missing parameters\", "
                "\"required\": [\"op\", \"a\", \"b\"], "
                "\"example\": \"/?op=add&a=5&b=3\", "
                "\"pid\": %d"
                "}",
                getpid());
        }
        
        // Free allocated memory
        free(operation);
        free(a_str);
        free(b_str);
    }
    
    // Send response
    send(client->client_socket, response, strlen(response), 0);
    
    // Cleanup
    close(client->client_socket);
    free(client);
    
    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\n", argv[0]);
        fprintf(stderr, "Example: %s 8005\n", argv[0]);
        return 1;
    }
    
    int port = atoi(argv[1]);
    printf("🧮 Calculator CGI Service starting on port %d (PID: %d)\n", port, getpid());
    
    // Create socket
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("Socket creation failed");
        return 1;
    }
    
    // Allow socket reuse
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    // Bind to port
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);
    
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("Bind failed");
        return 1;
    }
    
    // Listen for connections
    if (listen(server_fd, 10) < 0) {
        perror("Listen failed");
        return 1;
    }
    
    printf("🎯 Calculator service ready! Try:\n");
    printf("   curl \"http://localhost:%d/?op=add&a=10&b=5\"\n", port);
    printf("   curl \"http://localhost:%d/?op=divide&a=20&b=4\"\n", port);
    printf("   curl \"http://localhost:%d/\" (for help)\n", port);
    
    // Accept connections
    int addrlen = sizeof(address);
    while (1) {
        int client_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen);
        if (client_socket < 0) {
            perror("Accept failed");
            continue;
        }
        
        // Create thread to handle request
        pthread_t thread_id;
        client_info_t* client = malloc(sizeof(client_info_t));
        client->client_socket = client_socket;
        client->server_port = port;
        
        if (pthread_create(&thread_id, NULL, handle_request, client) != 0) {
            perror("Thread creation failed");
            close(client_socket);
            free(client);
            continue;
        }
        
        // Detach thread so it cleans up automatically
        pthread_detach(thread_id);
    }
    
    close(server_fd);
    return 0;
}