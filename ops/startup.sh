#!/bin/bash
#
# CGI Process Pool - System Startup Script
# Provides unified startup with dependency management and health checking
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
    echo "CGI Process Pool - System Startup"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --build        Build all services before starting (default: true)"
    echo "  --no-build     Skip build step"
    echo "  --cleanup      Clean up orphaned processes before starting"
    echo "  --monitor      Start with process monitoring (default)"
    echo "  --no-monitor   Start without monitoring"
    echo "  --config FILE  Use custom configuration file"
    echo "  --help         Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  CGI_POOL_CONFIG   Configuration file path"
    echo "  CGI_POOL_BUILD    Build services (true/false, default: true)"
    echo "  CGI_POOL_CLEANUP  Cleanup orphans (true/false, default: false)"
    echo ""
}

# Default options
BUILD_SERVICES=${CGI_POOL_BUILD:-true}
CLEANUP_ORPHANS=${CGI_POOL_CLEANUP:-false}
MONITOR_PROCESSES=true
CONFIG_FILE=${CGI_POOL_CONFIG:-"ops/process_config.json"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_SERVICES=true
            shift
            ;;
        --no-build)
            BUILD_SERVICES=false
            shift
            ;;
        --cleanup)
            CLEANUP_ORPHANS=true
            shift
            ;;
        --monitor)
            MONITOR_PROCESSES=true
            shift
            ;;
        --no-monitor)
            MONITOR_PROCESSES=false
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

echo "🚀 CGI Process Pool - System Startup"
echo "====================================="
echo ""
echo "Project Root: $PROJECT_ROOT"
echo "Config File:  $CONFIG_FILE"
echo "Build Services: $BUILD_SERVICES"
echo "Cleanup Orphans: $CLEANUP_ORPHANS"
echo "Monitor Processes: $MONITOR_PROCESSES"
echo ""

# Pre-flight checks
log_info "Performing pre-flight checks..."

# Check if required files exist
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

if [ ! -f "ops/process_manager.py" ]; then
    log_error "Process manager not found: ops/process_manager.py"
    exit 1
fi

# Check Python dependencies
if ! python3 -c "import requests" 2>/dev/null; then
    log_warning "Missing Python requests dependency."
    
    # Try different pip installation methods
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install requests
    elif command -v pip >/dev/null 2>&1; then
        pip install requests
    elif python3 -m pip --version >/dev/null 2>&1; then
        python3 -m pip install requests
    else
        log_error "pip not available. Please install python3-requests manually:"
        log_error "  Ubuntu/Debian: sudo apt install python3-requests"
        log_error "  Or manually install requests module"
        exit 1
    fi
fi

log_success "Pre-flight checks completed"

# Build services if requested
if [ "$BUILD_SERVICES" = true ]; then
    log_info "Building all services..."
    if make all; then
        log_success "Services built successfully"
    else
        log_error "Build failed"
        exit 1
    fi
fi

# Cleanup orphaned processes if requested
if [ "$CLEANUP_ORPHANS" = true ]; then
    log_info "Cleaning up orphaned processes..."
    python3 ops/process_manager.py cleanup --config "$CONFIG_FILE"
fi

# Start the system
log_info "Starting CGI Process Pool system..."

if [ "$MONITOR_PROCESSES" = true ]; then
    # Start with monitoring (blocks until shutdown)
    python3 ops/process_manager.py start --config "$CONFIG_FILE"
else
    # Start without monitoring (fire and forget)
    python3 ops/process_manager.py start --config "$CONFIG_FILE" --monitor-interval 0 &
    MANAGER_PID=$!
    echo $MANAGER_PID > /tmp/cgi_pool_manager.pid
    log_success "System started in background (PID: $MANAGER_PID)"
    log_info "Use './ops/shutdown.sh' to stop the system"
fi