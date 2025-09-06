#!/bin/bash

# Comprehensive Dependency Checker for CGI Process Pool
# Leverages the modular language system for dependency verification
# Usage: ./languages/check_dependencies.sh [options]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGER_SCRIPT="$SCRIPT_DIR/manager.py"
CHECK_ALL=false
VERBOSE=false
FIX_ISSUES=false
LANGUAGE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CHECK_ALL=true
            shift
            ;;
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --fix)
            FIX_ISSUES=true
            shift
            ;;
        --help)
            echo "Comprehensive Dependency Checker for CGI Process Pool"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --all              Check dependencies for all languages"
            echo "  --language LANG    Check dependencies for specific language"
            echo "  --verbose          Show detailed output"
            echo "  --fix              Attempt to auto-install missing dependencies"
            echo "  --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --all                    # Check all languages"
            echo "  $0 --language python        # Check Python dependencies"
            echo "  $0 --language csharp --fix  # Check C# and auto-install missing deps"
            echo ""
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Verify manager script exists
if [ ! -f "$MANAGER_SCRIPT" ]; then
    log_error "Language manager not found: $MANAGER_SCRIPT"
    exit 1
fi

echo "🔍 CGI Process Pool - Dependency Checker"
echo "========================================"
echo ""

# System-wide dependency checks
check_system_dependencies() {
    log_info "Checking system-wide dependencies..."
    
    # Check curl (used by testing systems)
    if command -v curl >/dev/null 2>&1; then
        log_success "curl available"
    else
        log_error "curl not found - required for testing"
        echo "   Install: sudo apt-get install curl (Ubuntu/Debian) or brew install curl (macOS)"
    fi
    
    # Check make
    if command -v make >/dev/null 2>&1; then
        log_success "make available"
    else
        log_error "make not found - required for build system"
        echo "   Install: sudo apt-get install make (Ubuntu/Debian) or xcode-select --install (macOS)"
    fi
    
    # Check jq (optional but recommended)
    if command -v jq >/dev/null 2>&1; then
        log_success "jq available (recommended)"
    else
        log_warning "jq not found - JSON parsing will use Python fallback"
        echo "   Install: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
    fi
    
    echo ""
}

# Check dependencies for a specific language
check_language_dependencies() {
    local language="$1"
    local fix_issues="$2"
    
    log_info "Checking $language dependencies..."
    
    if [ "$VERBOSE" = true ]; then
        python3 "$MANAGER_SCRIPT" check-deps --language "$language" --verbose
    else
        python3 "$MANAGER_SCRIPT" check-deps --language "$language"
    fi
    
    # Auto-install if requested
    if [ "$fix_issues" = true ]; then
        echo ""
        log_info "Attempting to auto-install missing dependencies for $language..."
        
        # Check what would be installed
        auto_install_output=$(python3 "$MANAGER_SCRIPT" install-deps --language "$language" --dry-run 2>/dev/null)
        
        if echo "$auto_install_output" | grep -q "Would run the following commands"; then
            echo "$auto_install_output"
            echo ""
            read -p "Proceed with installation? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                python3 "$MANAGER_SCRIPT" install-deps --language "$language"
                
                # Re-check after installation
                echo ""
                log_info "Re-checking $language dependencies after installation..."
                python3 "$MANAGER_SCRIPT" check-deps --language "$language"
            else
                log_info "Skipped auto-installation"
            fi
        else
            log_info "No auto-installable dependencies found for $language"
        fi
    fi
}

# Check all languages
check_all_languages() {
    log_info "Checking dependencies for all languages..."
    
    if [ "$VERBOSE" = true ]; then
        python3 "$MANAGER_SCRIPT" check-all-deps --verbose
    else
        python3 "$MANAGER_SCRIPT" check-all-deps
    fi
    
    if [ "$FIX_ISSUES" = true ]; then
        echo ""
        log_info "Auto-installation requested for all languages..."
        
        # Get list of languages
        languages=$(python3 "$MANAGER_SCRIPT" list | grep "  " | sed 's/^  \([^:]*\):.*/\1/')
        
        for lang in $languages; do
            echo ""
            echo "--- $lang ---"
            check_language_dependencies "$lang" true
        done
    fi
}

# Provide usage recommendations
provide_recommendations() {
    echo ""
    echo "📋 Recommendations:"
    echo "=================="
    
    # Check if this is being run from the correct directory
    if [ ! -f "Makefile" ]; then
        log_warning "Run this script from the project root directory"
        echo "   cd $(dirname "$SCRIPT_DIR") && ./languages/check_dependencies.sh"
    fi
    
    # Provide build system recommendations
    echo ""
    log_info "Next steps:"
    echo "   1. Fix any missing dependencies shown above"
    echo "   2. Run smoke tests: make smoke-test"
    echo "   3. Build services: make all"
    echo "   4. Start the system: make run-pool (in one terminal) && make run-yarp (in another)"
    echo ""
    log_info "For specific language setup:"
    echo "   ./languages/manager.py check-deps --language python --verbose"
    echo "   ./languages/manager.py install-deps --language csharp --dry-run"
}

# Main execution
main() {
    # Always check system dependencies first
    check_system_dependencies
    
    if [ "$CHECK_ALL" = true ]; then
        check_all_languages
    elif [ -n "$LANGUAGE" ]; then
        check_language_dependencies "$LANGUAGE" "$FIX_ISSUES"
    else
        # Default behavior - check all
        check_all_languages
    fi
    
    provide_recommendations
}

# Run main function
main "$@"