#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>
#include <time.h>

void handle_sigterm(int sig) {
    printf("Auth CGI process %d shutting down\n", getpid());
    exit(0);
}

void generate_token(char* token, int len) {
    const char charset[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    for (int i = 0; i < len - 1; i++) {
        token[i] = charset[rand() % (sizeof(charset) - 1)];
    }
    token[len - 1] = '\0';
}

void send_response(int client_socket, const char* user) {
    char token[33];
    generate_token(token, sizeof(token));
    
    char body[512];
    char response[1024];
    
    snprintf(body, sizeof(body),
        "{\"user\": \"%s\", \"token\": \"%s\", \"pid\": %d, \"expires\": %ld}",
        user, token, getpid(), time(NULL) + 3600);
    
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
    srand(time(NULL) ^ getpid());
    
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
    
    printf("Auth CGI process %d listening on port %d\n", getpid(), port);
    
    while (1) {
        int client_socket = accept(server_socket, NULL, NULL);
        if (client_socket < 0) {
            continue;
        }
        
        char buffer[1024] = {0};
        recv(client_socket, buffer, sizeof(buffer) - 1, 0);
        
        char* user_start = strstr(buffer, "GET ");
        char user[256] = "anonymous";
        
        if (user_start) {
            char* u_param = strstr(user_start, "user=");
            if (u_param) {
                u_param += 5;
                int i = 0;
                while (u_param[i] && u_param[i] != ' ' && u_param[i] != '&' && i < 255) {
                    user[i] = u_param[i];
                    i++;
                }
                user[i] = '\0';
            }
        }
        
        send_response(client_socket, user);
        close(client_socket);
    }
    
    close(server_socket);
    return 0;
}