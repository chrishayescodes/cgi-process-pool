CC = gcc
CFLAGS = -Wall -O2 -pthread
TARGETS = search.cgi auth.cgi

.PHONY: all clean test run-pool run-demo run-yarp check-deps

all: $(TARGETS)

search.cgi: search.c
	$(CC) $(CFLAGS) -o $@ $<
	@echo "✓ Built search.cgi"

auth.cgi: auth.c
	$(CC) $(CFLAGS) -o $@ $<
	@echo "✓ Built auth.cgi"

clean:
	rm -f $(TARGETS)
	rm -f /tmp/cgi_upstreams.conf
	@echo "✓ Cleaned build artifacts"

test: all
	@echo "Testing search.cgi..."
	@./search.cgi 9000 &
	@PID=$$!; \
	sleep 1; \
	curl -s "http://localhost:9000?q=test" | grep -q "results" && echo "✓ search.cgi test passed" || echo "✗ search.cgi test failed"; \
	kill $$PID 2>/dev/null || true
	
	@echo "Testing auth.cgi..."
	@./auth.cgi 9001 &
	@PID=$$!; \
	sleep 1; \
	curl -s "http://localhost:9001?user=test" | grep -q "token" && echo "✓ auth.cgi test passed" || echo "✗ auth.cgi test failed"; \
	kill $$PID 2>/dev/null || true

run-pool: all
	python3 pool_manager.py

run-demo: all
	chmod +x demo.sh
	./demo.sh

run-yarp: all
	@echo "Starting YARP proxy with integrated admin dashboard on port 8080..."
	@echo "Ensure CGI pool is running first with 'make run-pool'"
	@echo "Admin dashboard will be available at http://localhost:8080/admin"
	cd proxy/CGIProxy && dotnet run --urls="http://0.0.0.0:8080"

install-deps:
	@echo "Installing Python dependencies..."
	pip3 install requests
	@echo "✓ Dependencies installed"

check-deps:
	@./check_dependencies.sh

help:
	@echo "CGI Process Pool - Makefile targets:"
	@echo "  make all        - Build all CGI executables"
	@echo "  make clean      - Remove built files"
	@echo "  make test       - Run basic tests on CGI executables"
	@echo "  make check-deps - Check if all dependencies are installed"
	@echo "  make install-deps - Install Python dependencies"
	@echo "  make run-pool   - Start the CGI pool manager"
	@echo "  make run-yarp   - Start YARP proxy with integrated admin dashboard"
	@echo "  make run-demo   - Run the nginx demo (legacy)"
	@echo "  make help       - Show this help message"
	@echo ""
	@echo "Recommended workflow:"
	@echo "  1. make run-pool   (start CGI processes)"
	@echo "  2. make run-yarp   (start YARP proxy with admin at :8080/admin)"