#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>
#include <time.h>

void handle_sigterm(int sig) {
    printf("Search CGI process %d shutting down\n", getpid());
    exit(0);
}

void send_response(int client_socket, const char* query) {
    char body[512];
    char response[1024];
    
    snprintf(body, sizeof(body),
        "{\"query\": \"%s\", \"results\": [\"result1\", \"result2\", \"result3\"], \"pid\": %d, \"timestamp\": %ld}",
        query, getpid(), time(NULL));
    
    snprintf(response, sizeof(response),
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: %ld\r\n"
        "Connection: close\r\n"
        "\r\n"
        "%s",
        strlen(body), body);
    
    send(client_socket, response, strlen(response), 0);
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\n", argv[0]);
        exit(1);
    }
    
    signal(SIGTERM, handle_sigterm);
    signal(SIGINT, handle_sigterm);
    
    int port = atoi(argv[1]);
    int server_socket = socket(AF_INET, SOCK_STREAM, 0);
    
    if (server_socket < 0) {
        perror("Socket creation failed");
        exit(1);
    }
    
    int opt = 1;
    if (setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        perror("Setsockopt failed");
        exit(1);
    }
    
    struct sockaddr_in address = {
        .sin_family = AF_INET,
        .sin_addr.s_addr = INADDR_ANY,
        .sin_port = htons(port)
    };
    
    if (bind(server_socket, (struct sockaddr*)&address, sizeof(address)) < 0) {
        perror("Bind failed");
        exit(1);
    }
    
    if (listen(server_socket, 10) < 0) {
        perror("Listen failed");
        exit(1);
    }
    
    printf("Search CGI process %d listening on port %d\n", getpid(), port);
    
    while (1) {
        int client_socket = accept(server_socket, NULL, NULL);
        if (client_socket < 0) {
            continue;
        }
        
        char buffer[1024] = {0};
        recv(client_socket, buffer, sizeof(buffer) - 1, 0);
        
        char* query_start = strstr(buffer, "GET ");
        char query[256] = "default";
        
        if (query_start) {
            char* q_param = strstr(query_start, "q=");
            if (q_param) {
                q_param += 2;
                int i = 0;
                while (q_param[i] && q_param[i] != ' ' && q_param[i] != '&' && i < 255) {
                    query[i] = q_param[i];
                    i++;
                }
                query[i] = '\0';
            }
        }
        
        send_response(client_socket, query);
        close(client_socket);
    }
    
    close(server_socket);
    return 0;
}