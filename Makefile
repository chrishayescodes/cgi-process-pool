# Dynamic Makefile for CGI Process Pool
# Uses sample_discovery.py to automatically discover and build samples

CC = gcc
CFLAGS = -Wall -O2 -pthread
BUILD_DIR = build

# Dynamically discover targets from manifest.json
TARGETS := $(shell ./discovery/discovery.py targets 2>/dev/null || echo "build/search.cgi build/auth.cgi")

.PHONY: all clean test run-pool run-demo run-yarp check-deps samples discover

all: $(BUILD_DIR) $(TARGETS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Include dynamically generated rules
-include Makefile.rules

# Generate build rules from manifest.json
Makefile.rules: discovery/manifest.json discovery/discovery.py
	@echo "# Auto-generated build rules from manifest.json" > $@
	@echo "# Generated at: $$(date)" >> $@
	@./discovery/discovery.py rules >> $@ 2>/dev/null || echo "# Failed to generate rules" >> $@
	@echo "✓ Generated build rules from manifest.json"

clean:
	rm -rf $(BUILD_DIR)
	rm -f /tmp/cgi_upstreams.conf
	rm -f Makefile.rules
	@echo "✓ Cleaned build artifacts"

# Discovery commands
discover:
	@echo "🔍 Discovering applications from manifest.json..."
	@./discovery/discovery.py list

discover-c:
	@echo "🔍 C language applications:"
	@./discovery/discovery.py list --language c

discover-python:
	@echo "🔍 Python language applications:"
	@./discovery/discovery.py list --language python

discover-csharp:
	@echo "🔍 C# script applications:"
	@./discovery/discovery.py list --language csharp

sample-info:
	@if [ -z "$(SAMPLE)" ]; then \
		echo "Usage: make sample-info SAMPLE=<name>"; \
		echo "Available applications:"; \
		./discovery/discovery.py list --format text; \
	else \
		./discovery/discovery.py info --name $(SAMPLE); \
	fi

# Generate pool configuration
pool-config:
	@echo "📋 Pool Manager Configuration:"
	@./discovery/discovery.py pool-config

test: all
	@echo "Testing discovered samples..."
	@for target in $(TARGETS); do \
		echo "Testing $$target..."; \
		if [ -f "$$target" ]; then \
			base=$$(basename $$target .cgi); \
			port=$$((9000 + $$RANDOM % 1000)); \
			./$$target $$port & \
			PID=$$!; \
			sleep 1; \
			if [ "$$base" = "search" ]; then \
				curl -s "http://localhost:$$port?q=test" | grep -q "results" && echo "✓ $$target test passed" || echo "✗ $$target test failed"; \
			elif [ "$$base" = "auth" ]; then \
				curl -s "http://localhost:$$port?user=test" | grep -q "token" && echo "✓ $$target test passed" || echo "✗ $$target test failed"; \
			fi; \
			kill $$PID 2>/dev/null || true; \
		fi; \
	done

smoke-test:
	@echo "🔍 Running smoke tests on all endpoints..."
	@./testing/smoketest.sh

smoke-test-verbose:
	@echo "🔍 Running smoke tests with verbose output..."
	@./testing/smoketest.sh --verbose

samples:
	@echo "📋 Available applications in manifest:"
	@./discovery/discovery.py list

samples-info:
	@echo "📋 Application Manifest Information:"
	@cat manifest.json | python3 -m json.tool

# Add new sample to registry
add-sample:
	@echo "🎯 To add a new application:"
	@echo "1. Add your source file anywhere (apps can live anywhere)"
	@echo "2. Update manifest.json with application metadata"
	@echo "3. Run 'make' to build (C apps will auto-build)"
	@echo ""
	@echo "Example entry for manifest.json:"
	@echo '  "my_service": {'
	@echo '    "name": "My Service",'
	@echo '    "description": "Description here",'
	@echo '    "language": "c",'
	@echo '    "type": "core",'
	@echo '    "path": "src/my_service.c",'
	@echo '    "executable": "my_service.cgi",'
	@echo '    "default_ports": [8003, 8004]'
	@echo '  }'

run-pool: all
	python3 pool/manager.py

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
	@echo "CGI Process Pool - Dynamic Makefile"
	@echo ""
	@echo "Discovery Commands:"
	@echo "  make discover       - List all discovered samples"
	@echo "  make discover-c     - List C language samples"
	@echo "  make discover-python - List Python language samples"
	@echo "  make discover-csharp - List C# script samples"
	@echo "  make sample-info SAMPLE=<name> - Show details about a sample"
	@echo "  make pool-config    - Show pool manager configuration"
	@echo "  make add-sample     - Instructions for adding new samples"
	@echo ""
	@echo "Build Commands:"
	@echo "  make all           - Build all discovered CGI executables"
	@echo "  make clean         - Remove built files and generated rules"
	@echo "  make test          - Run tests on discovered samples"
	@echo "  make smoke-test    - Run smoke tests on all endpoints"
	@echo "  make smoke-test-verbose - Run smoke tests with verbose output"
	@echo ""
	@echo "Runtime Commands:"
	@echo "  make run-pool      - Start the CGI pool manager"
	@echo "  make run-yarp      - Start YARP proxy with admin dashboard"
	@echo ""
	@echo "Service Addition Commands:"
	@echo "  ./add_cgi_app.sh <name> <port> [instances]        - Add C service"
	@echo "  ./add_python_cgi_app.sh <name> <port> [instances] - Add Python service"
	@echo "  ./add_csharp_cgi_app.sh <name> <port> [instances] - Add C# script service"
	@echo ""
	@echo "Other Commands:"
	@echo "  make check-deps    - Check if all dependencies are installed"
	@echo "  make install-deps  - Install Python dependencies"
	@echo "  make help          - Show this help message"
	@echo ""
	@echo "The build system automatically discovers samples from manifest.json"
	@echo "and generates appropriate build rules. Edit manifest.json to add new services."