#!/bin/bash

# Smoke Test Suite for CGI Process Pool
# Tests all endpoints from manifest.json and main system endpoints for startup sanity
# Usage: ./testing/smoketest.sh [--proxy-url http://localhost:8080] [--timeout 5] [--verbose]

set -e

# Default configuration
PROXY_URL="http://localhost:8080"
TIMEOUT=5
VERBOSE=false
MANIFEST_PATH="discovery/manifest.json"
FAILED_TESTS=0
TOTAL_TESTS=0
TEST_RESULTS=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --proxy-url)
            PROXY_URL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Smoke Test Suite for CGI Process Pool"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --proxy-url URL    Proxy URL to test (default: http://localhost:8080)"
            echo "  --timeout SEC      Request timeout in seconds (default: 5)"
            echo "  --verbose          Enable verbose output"
            echo "  --help            Show this help message"
            echo ""
            echo "Tests performed:"
            echo "  1. Main system endpoints (/, /admin, /admin-api/health)"
            echo "  2. All service endpoints from manifest.json"
            echo "  3. Health checks for all services"
            echo "  4. Example requests from manifest.json"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Color codes for output
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

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "   $1"
    fi
}

# Test execution function
run_test() {
    local test_name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    local expected_content="$4"
    local method="${5:-GET}"
    local data="$6"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log_verbose "Testing: $test_name"
    log_verbose "URL: $url"
    log_verbose "Method: $method"
    
    # Build curl command
    local curl_cmd="curl -s -w '%{http_code}|%{time_total}' --connect-timeout $TIMEOUT --max-time $((TIMEOUT * 2))"
    
    if [ "$method" = "POST" ]; then
        curl_cmd="$curl_cmd -X POST -H 'Content-Type: application/json'"
        if [ -n "$data" ]; then
            curl_cmd="$curl_cmd -d '$data'"
        fi
    fi
    
    curl_cmd="$curl_cmd '$url'"
    
    # Execute request
    local response=$(eval $curl_cmd 2>/dev/null || echo "CURL_ERROR|0")
    
    # Parse response - format is: body + status_code|response_time
    local last_line=$(echo "$response" | tail -c 20)
    local status_code=$(echo "$last_line" | grep -o '[0-9][0-9][0-9]|[0-9.]*$' | cut -d'|' -f1 || echo "UNKNOWN")
    local response_time=$(echo "$last_line" | grep -o '[0-9][0-9][0-9]|[0-9.]*$' | cut -d'|' -f2 || echo "0")
    
    # Extract body by removing the status line
    local body=$(echo "$response" | sed 's/[0-9][0-9][0-9]|[0-9.]*$//' || echo "$response")
    
    log_verbose "Status: $status_code, Time: ${response_time}s"
    
    # Check results
    local test_passed=true
    local failure_reason=""
    
    if [ "$response" = "CURL_ERROR|0" ]; then
        test_passed=false
        failure_reason="Connection failed"
    elif [ "$status_code" != "$expected_status" ]; then
        test_passed=false
        failure_reason="Expected status $expected_status, got $status_code"
    elif [ -n "$expected_content" ] && ! echo "$body" | grep -q "$expected_content"; then
        test_passed=false
        failure_reason="Expected content '$expected_content' not found"
    fi
    
    # Record results
    if [ "$test_passed" = true ]; then
        log_success "$test_name (${response_time}s)"
        TEST_RESULTS+=("✅ $test_name")
    else
        log_error "$test_name - $failure_reason"
        TEST_RESULTS+=("❌ $test_name - $failure_reason")
        FAILED_TESTS=$((FAILED_TESTS + 1))
        
        if [ "$VERBOSE" = true ] && [ ${#body} -gt 0 ]; then
            log_verbose "Response body: $body"
        fi
    fi
}

# Check if manifest.json exists
check_manifest() {
    if [ ! -f "$MANIFEST_PATH" ]; then
        log_error "Manifest file not found: $MANIFEST_PATH"
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_warning "jq not installed. Using python for JSON parsing."
        JSON_PARSER="python3 -c"
    else
        JSON_PARSER="jq -r"
    fi
}

# Parse manifest.json and extract service information
get_services_from_manifest() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.samples | to_entries[] | "\(.key)|\(.value.api_endpoint)|\(.value.health_check // "")|\(.value.examples // [] | join(" ; "))"' "$MANIFEST_PATH"
    else
        python3 -c "
import json
with open('$MANIFEST_PATH', 'r') as f:
    data = json.load(f)
for key, value in data.get('samples', {}).items():
    endpoint = value.get('api_endpoint', '')
    health = value.get('health_check', '')
    examples = ' ; '.join(value.get('examples', []))
    print(f'{key}|{endpoint}|{health}|{examples}')
"
    fi
}

# Test main system endpoints
test_main_endpoints() {
    log_info "Testing main system endpoints..."
    
    # Test root endpoint (should redirect to admin or return admin dashboard)
    run_test "Root Endpoint" "$PROXY_URL/" "200"
    
    # Test admin dashboard
    run_test "Admin Dashboard" "$PROXY_URL/admin" "200"
    
    # Test admin API health check
    run_test "Admin API Health" "$PROXY_URL/admin-api/health" "200" "healthy"
}

# Test service endpoints from manifest
test_service_endpoints() {
    log_info "Testing service endpoints from manifest.json..."
    
    while IFS='|' read -r service_name api_endpoint health_check examples; do
        if [ -z "$service_name" ] || [ -z "$api_endpoint" ]; then
            continue
        fi
        
        log_verbose "Testing service: $service_name"
        
        # Test basic API endpoint
        run_test "$service_name API" "$PROXY_URL$api_endpoint" "200"
        
        # Test health check if available
        if [ -n "$health_check" ]; then
            local health_url="$PROXY_URL$api_endpoint$health_check"
            run_test "$service_name Health Check" "$health_url" "200"
        fi
        
        # Test examples if available
        if [ -n "$examples" ]; then
            echo "$examples" | tr ';' '\n' | while IFS= read -r example; do
                example=$(echo "$example" | xargs) # trim whitespace
                if [[ "$example" =~ curl.*\"([^\"]+)\" ]]; then
                    local example_url=$(echo "$example" | sed 's/.*"\([^"]*\)".*/\1/')
                    # Convert localhost:8080 to our proxy URL
                    example_url=$(echo "$example_url" | sed "s|http://localhost:8080|$PROXY_URL|")
                    
                    # Extract method and data for POST requests
                    if [[ "$example" =~ -X\ POST ]]; then
                        local post_data=""
                        if [[ "$example" =~ -d\ \'([^\']+)\' ]]; then
                            post_data=$(echo "$example" | sed "s/.*-d '\([^']*\)'.*/\1/")
                        fi
                        run_test "$service_name Example (POST)" "$example_url" "200" "" "POST" "$post_data"
                    else
                        run_test "$service_name Example" "$example_url" "200"
                    fi
                fi
            done
        fi
        
    done < <(get_services_from_manifest)
}

# Test direct service ports (bypass proxy)
test_direct_services() {
    log_info "Testing direct service ports..."
    
    while IFS='|' read -r service_name api_endpoint health_check examples; do
        if [ -z "$service_name" ]; then
            continue
        fi
        
        # Get default ports from manifest
        local ports
        if command -v jq >/dev/null 2>&1; then
            ports=$(jq -r ".samples.${service_name}.default_ports[]?" "$MANIFEST_PATH" 2>/dev/null || echo "")
        else
            ports=$(python3 -c "
import json
try:
    with open('$MANIFEST_PATH', 'r') as f:
        data = json.load(f)
    for port in data.get('samples', {}).get('$service_name', {}).get('default_ports', []):
        print(port)
except:
    pass
")
        fi
        
        for port in $ports; do
            if [ -n "$port" ] && [ "$port" != "null" ]; then
                local direct_url="http://localhost:$port"
                if [ -n "$health_check" ]; then
                    direct_url="$direct_url$health_check"
                else
                    direct_url="$direct_url/"
                fi
                
                run_test "$service_name Direct Port $port" "$direct_url" "200"
            fi
        done
        
    done < <(get_services_from_manifest)
}

# Test system dependencies
test_dependencies() {
    log_info "Testing system dependencies..."
    
    # Check if pool manager is running (by testing if any service responds)
    local service_responding=false
    
    while IFS='|' read -r service_name api_endpoint health_check examples; do
        if [ -z "$service_name" ]; then
            continue
        fi
        
        # Try to connect to first default port
        local first_port
        if command -v jq >/dev/null 2>&1; then
            first_port=$(jq -r ".samples.${service_name}.default_ports[0]?" "$MANIFEST_PATH" 2>/dev/null)
        else
            first_port=$(python3 -c "
import json
try:
    with open('$MANIFEST_PATH', 'r') as f:
        data = json.load(f)
    ports = data.get('samples', {}).get('$service_name', {}).get('default_ports', [])
    if ports:
        print(ports[0])
except:
    pass
")
        fi
        
        if [ -n "$first_port" ] && [ "$first_port" != "null" ]; then
            if curl -s --connect-timeout 2 "http://localhost:$first_port/" >/dev/null 2>&1; then
                service_responding=true
                break
            fi
        fi
    done < <(get_services_from_manifest)
    
    if [ "$service_responding" = true ]; then
        log_success "Pool Manager Services"
        TEST_RESULTS+=("✅ Pool Manager Services")
    else
        log_error "Pool Manager Services - No services responding"
        TEST_RESULTS+=("❌ Pool Manager Services - No services responding")
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Print summary
print_summary() {
    echo ""
    echo "===================="
    echo "SMOKE TEST SUMMARY"
    echo "===================="
    echo ""
    
    local passed_tests=$((TOTAL_TESTS - FAILED_TESTS))
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "All $TOTAL_TESTS tests passed! 🎉"
    else
        log_error "$FAILED_TESTS out of $TOTAL_TESTS tests failed"
    fi
    
    echo ""
    echo "Test Results:"
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result"
    done
    
    echo ""
    echo "System Status:"
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}✅ System appears to be healthy${NC}"
    elif [ $FAILED_TESTS -lt $((TOTAL_TESTS / 2)) ]; then
        echo -e "${YELLOW}⚠️  System has some issues but is partially functional${NC}"
    else
        echo -e "${RED}❌ System has major issues${NC}"
    fi
    
    echo ""
    echo "Next steps:"
    if [ $FAILED_TESTS -gt 0 ]; then
        echo "1. Check failed services with: make run-pool"
        echo "2. Verify YARP proxy with: make run-yarp"
        echo "3. Review logs for specific error details"
        echo "4. Run tests individually with --verbose for more details"
    else
        echo "1. System ready for production traffic"
        echo "2. Monitor with: $PROXY_URL/admin"
        echo "3. Consider running load tests: ./testing/stress_test.sh"
    fi
}

# Main execution
main() {
    echo "🔍 CGI Process Pool Smoke Test Suite"
    echo "====================================="
    echo ""
    echo "Proxy URL: $PROXY_URL"
    echo "Timeout: ${TIMEOUT}s"
    echo "Manifest: $MANIFEST_PATH"
    echo ""
    
    check_manifest
    
    # Run test suites
    test_dependencies
    test_main_endpoints  
    test_service_endpoints
    test_direct_services
    
    print_summary
    
    # Exit with error code if tests failed
    exit $FAILED_TESTS
}

# Run main function
main "$@"