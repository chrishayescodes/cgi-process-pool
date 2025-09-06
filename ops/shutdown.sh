#!/bin/bash
#
# CGI Process Pool - System Shutdown Script  
# Provides unified shutdown with graceful termination and cleanup
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_usage() {
    echo "CGI Process Pool - System Shutdown"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --force        Force shutdown (SIGKILL) if graceful fails"
    echo "  --cleanup      Clean up all orphaned processes"
    echo "  --config FILE  Use custom configuration file"
    echo "  --help         Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  CGI_POOL_CONFIG   Configuration file path"
    echo "  CGI_POOL_FORCE    Force shutdown (true/false, default: false)"
    echo ""
}

# Default options
FORCE_SHUTDOWN=${CGI_POOL_FORCE:-false}
CLEANUP_ALL=false
CONFIG_FILE=${CGI_POOL_CONFIG:-"ops/process_config.json"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_SHUTDOWN=true
            shift
            ;;
        --cleanup)
            CLEANUP_ALL=true
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Change to project root
cd "$PROJECT_ROOT"

echo "🛑 CGI Process Pool - System Shutdown"
echo "======================================"
echo ""
echo "Project Root: $PROJECT_ROOT"
echo "Config File:  $CONFIG_FILE"
echo "Force Shutdown: $FORCE_SHUTDOWN"
echo "Cleanup All: $CLEANUP_ALL"
echo ""

# Check if process manager exists
if [ ! -f "ops/process_manager.py" ]; then
    log_error "Process manager not found: ops/process_manager.py"
    exit 1
fi

# Stop managed processes
if [ -f "$CONFIG_FILE" ]; then
    log_info "Stopping managed processes..."
    python3 ops/process_manager.py stop --config "$CONFIG_FILE"
else
    log_warning "Config file not found: $CONFIG_FILE"
fi

# Stop background manager if running
if [ -f "/tmp/cgi_pool_manager.pid" ]; then
    MANAGER_PID=$(cat /tmp/cgi_pool_manager.pid)
    if kill -0 "$MANAGER_PID" 2>/dev/null; then
        log_info "Stopping background process manager (PID: $MANAGER_PID)..."
        kill "$MANAGER_PID" 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        if kill -0 "$MANAGER_PID" 2>/dev/null; then
            log_warning "Force killing process manager..."
            kill -9 "$MANAGER_PID" 2>/dev/null || true
        fi
    fi
    rm -f "/tmp/cgi_pool_manager.pid"
fi

# Cleanup all CGI-related processes if requested or forced
if [ "$CLEANUP_ALL" = true ] || [ "$FORCE_SHUTDOWN" = true ]; then
    log_info "Cleaning up all CGI-related processes..."
    
    # Find and terminate CGI processes
    CLEANUP_PATTERNS=(
        "\.cgi"
        "sample_python_cgi\.py"
        "sample_csharp_cgi\.csx"
        "dotnet-script.*\.csx"
        "pool/manager\.py"
        "dotnet run.*8080"
    )
    
    for pattern in "${CLEANUP_PATTERNS[@]}"; do
        PIDS=$(pgrep -f "$pattern" 2>/dev/null || true)
        if [ -n "$PIDS" ]; then
            log_info "Terminating processes matching: $pattern"
            echo "$PIDS" | while read -r pid; do
                if [ -n "$pid" ]; then
                    log_info "Killing process $pid..."
                    if [ "$FORCE_SHUTDOWN" = true ]; then
                        kill -9 "$pid" 2>/dev/null || true
                    else
                        kill "$pid" 2>/dev/null || true
                        sleep 1
                        # Force kill if still running
                        if kill -0 "$pid" 2>/dev/null; then
                            kill -9 "$pid" 2>/dev/null || true
                        fi
                    fi
                fi
            done
        fi
    done
    
    # Additional cleanup using process manager
    python3 ops/process_manager.py cleanup --config "$CONFIG_FILE" 2>/dev/null || true
fi

# Clean up temporary files
log_info "Cleaning up temporary files..."
rm -f /tmp/cgi_upstreams.conf
rm -f /tmp/cgi_pool_*.pid

# Verify shutdown
log_info "Verifying shutdown..."
REMAINING_PROCESSES=$(pgrep -f "(\.cgi|sample.*cgi|pool/manager\.py|dotnet run.*8080)" 2>/dev/null || true)

if [ -n "$REMAINING_PROCESSES" ]; then
    log_warning "Some processes may still be running:"
    echo "$REMAINING_PROCESSES" | while read -r pid; do
        if [ -n "$pid" ]; then
            ps -p "$pid" -o pid,cmd 2>/dev/null || true
        fi
    done
    
    if [ "$FORCE_SHUTDOWN" = true ]; then
        log_info "Force killing remaining processes..."
        echo "$REMAINING_PROCESSES" | xargs -r kill -9 2>/dev/null || true
    fi
else
    log_success "All processes stopped successfully"
fi

echo ""
log_success "System shutdown completed"