#!/bin/bash

# CGI Process Pool Stress Test
# Tests load balancing, concurrency, and system resilience

set -e

# Configuration
YARP_URL="http://localhost:8080"
CONCURRENT_REQUESTS=50
TOTAL_REQUESTS=200
DELAY_BETWEEN_BATCHES=0.1
TEST_DURATION=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_RESPONSE_TIME=0
RESPONSE_COUNT=0
CSHARP_AVAILABLE=false

echo -e "${BLUE}🧪 CGI Process Pool Stress Test${NC}"
echo "========================================"
echo -e "Target: ${YARP_URL}"
echo -e "Concurrent requests: ${CONCURRENT_REQUESTS}"
echo -e "Total requests: ${TOTAL_REQUESTS}"
echo -e "Test duration: ${TEST_DURATION}s"
echo ""

# Check if system is running
check_system() {
    echo -e "${YELLOW}🔍 Checking system availability...${NC}"
    
    if ! curl -s "${YARP_URL}/api/search?q=test" > /dev/null; then
        echo -e "${RED}❌ System not responding. Please start the system:${NC}"
        echo -e "  Terminal 1: make run-pool"
        echo -e "  Terminal 2: make run-yarp"
        exit 1
    fi
    
    if ! curl -s "${YARP_URL}/api/auth?user=test" > /dev/null; then
        echo -e "${RED}❌ Auth service not responding${NC}"
        exit 1
    fi

    # Check C# script service if available
    if curl -s "${YARP_URL}/api/csharp?service=test" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ C# script service available${NC}"
        CSHARP_AVAILABLE=true
    else
        echo -e "${YELLOW}ℹ️  C# script service not available (optional)${NC}"
        CSHARP_AVAILABLE=false
    fi
    
    echo -e "${GREEN}✅ System is running${NC}"
}

# Single request test function
test_request() {
    local service="$1"
    local params="$2"
    local expected_field="$3"
    local start_time=$(date +%s%N)
    
    local response=$(curl -s "${YARP_URL}/api/${service}?${params}" 2>/dev/null)
    local end_time=$(date +%s%N)
    local response_time=$(( (end_time - start_time) / 1000000 ))  # Convert to ms
    
    TOTAL_RESPONSE_TIME=$((TOTAL_RESPONSE_TIME + response_time))
    RESPONSE_COUNT=$((RESPONSE_COUNT + 1))
    
    if echo "$response" | grep -q "$expected_field"; then
        echo "$response_time"  # Return response time for successful requests
        return 0
    else
        echo "ERROR"
        return 1
    fi
}

# Load balancing test
test_load_balancing() {
    echo -e "${YELLOW}⚖️  Testing load balancing...${NC}"
    
    local pids=()
    local search_pids=0
    local auth_pids=0
    
    # Collect PIDs from multiple requests
    for i in {1..10}; do
        local response=$(curl -s "${YARP_URL}/api/search?q=loadtest$i" 2>/dev/null)
        local pid=$(echo "$response" | grep -o '"pid":[0-9]*' | cut -d: -f2)
        if [[ -n "$pid" ]]; then
            pids+=("$pid")
        fi
    done
    
    # Count unique PIDs
    local unique_pids=$(printf '%s\n' "${pids[@]}" | sort -u | wc -l)
    
    if [[ $unique_pids -gt 1 ]]; then
        echo -e "${GREEN}✅ Load balancing working: $unique_pids different processes handling requests${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Load balancing not working: only 1 process handling requests${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Concurrent requests test
test_concurrency() {
    echo -e "${YELLOW}🚀 Testing concurrent requests (${CONCURRENT_REQUESTS} concurrent)...${NC}"
    
    local success_count=0
    local error_count=0
    local response_times=()
    
    # Create temp file for results
    local results_file=$(mktemp)
    
    # Launch concurrent requests
    for ((i=1; i<=CONCURRENT_REQUESTS; i++)); do
        (
            # Distribute requests across available services
            if [[ "$CSHARP_AVAILABLE" == "true" ]]; then
                # Include C# script in rotation
                case $((i % 3)) in
                    0) service="search"; params="q=concurrent$i"; expected="results" ;;
                    1) service="auth"; params="user=test$i"; expected="token" ;;
                    2) service="csharp"; params="service=test&data=concurrent$i"; expected="script_type" ;;
                esac
            else
                # Original behavior without C# script
                local service=$( [ $((i % 2)) -eq 0 ] && echo "search" || echo "auth" )
                local params=$( [ "$service" = "search" ] && echo "q=concurrent$i" || echo "user=test$i" )
                local expected=$( [ "$service" = "search" ] && echo "results" || echo "token" )
            fi
            
            local result=$(test_request "$service" "$params" "$expected")
            echo "$result" >> "$results_file"
        ) &
        
        # Limit concurrent processes to avoid overwhelming system
        if [[ $((i % 10)) -eq 0 ]]; then
            wait
            sleep $DELAY_BETWEEN_BATCHES
        fi
    done
    
    wait  # Wait for all background processes
    
    # Analyze results
    while read -r result; do
        if [[ "$result" = "ERROR" ]]; then
            error_count=$((error_count + 1))
        else
            success_count=$((success_count + 1))
            response_times+=("$result")
        fi
    done < "$results_file"
    
    rm -f "$results_file"
    
    local success_rate=$(( success_count * 100 / CONCURRENT_REQUESTS ))
    
    if [[ $success_rate -ge 95 ]]; then
        echo -e "${GREEN}✅ Concurrency test passed: ${success_count}/${CONCURRENT_REQUESTS} requests successful (${success_rate}%)${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Concurrency test failed: ${success_count}/${CONCURRENT_REQUESTS} requests successful (${success_rate}%)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Calculate response time statistics
    if [[ ${#response_times[@]} -gt 0 ]]; then
        local min_time=${response_times[0]}
        local max_time=${response_times[0]}
        local total_time=0
        
        for time in "${response_times[@]}"; do
            total_time=$((total_time + time))
            [[ $time -lt $min_time ]] && min_time=$time
            [[ $time -gt $max_time ]] && max_time=$time
        done
        
        local avg_time=$((total_time / ${#response_times[@]}))
        echo -e "   Response times: min=${min_time}ms, avg=${avg_time}ms, max=${max_time}ms"
    fi
}

# Sustained load test
test_sustained_load() {
    echo -e "${YELLOW}⏱️  Testing sustained load for ${TEST_DURATION}s...${NC}"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + TEST_DURATION))
    local request_count=0
    local error_count=0
    
    echo -e "Progress: [${BLUE}"
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local current_time=$(date +%s)
        local progress=$(( (current_time - start_time) * 20 / TEST_DURATION ))
        
        # Update progress bar
        printf "\r${YELLOW}Progress: [${BLUE}"
        for ((i=0; i<progress; i++)); do printf "█"; done
        for ((i=progress; i<20; i++)); do printf "░"; done
        printf "${YELLOW}] %d/%ds${NC}" "$((current_time - start_time))" "$TEST_DURATION"
        
        # Send batch of requests
        for i in {1..5}; do
            (
                # Distribute requests across available services
                if [[ "$CSHARP_AVAILABLE" == "true" ]]; then
                    # Include C# script in rotation
                    case $((request_count % 3)) in
                        0) service="search"; params="q=sustained$request_count"; expected="results" ;;
                        1) service="auth"; params="user=load$request_count"; expected="token" ;;
                        2) service="csharp"; params="service=load&data=sustained$request_count"; expected="script_type" ;;
                    esac
                else
                    # Original behavior without C# script
                    local service=$( [ $((request_count % 2)) -eq 0 ] && echo "search" || echo "auth" )
                    local params=$( [ "$service" = "search" ] && echo "q=sustained$request_count" || echo "user=load$request_count" )
                    local expected=$( [ "$service" = "search" ] && echo "results" || echo "token" )
                fi
                
                if ! test_request "$service" "$params" "$expected" > /dev/null; then
                    error_count=$((error_count + 1))
                fi
            ) &
        done
        
        request_count=$((request_count + 5))
        sleep 0.2
    done
    
    wait  # Wait for remaining requests
    
    echo -e "\n"
    
    local error_rate=$(( error_count * 100 / request_count ))
    local requests_per_second=$(( request_count / TEST_DURATION ))
    
    if [[ $error_rate -le 5 ]]; then
        echo -e "${GREEN}✅ Sustained load test passed: ${request_count} requests, ${error_count} errors (${error_rate}%)${NC}"
        echo -e "   Average throughput: ${requests_per_second} req/s"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Sustained load test failed: ${request_count} requests, ${error_count} errors (${error_rate}%)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Health monitoring test
test_health_monitoring() {
    echo -e "${YELLOW}🏥 Testing health monitoring endpoints...${NC}"
    
    local health_endpoints=(
        "/api/metrics/summary"
        "/api/metrics"
        "/health"
    )
    
    local working_endpoints=0
    
    for endpoint in "${health_endpoints[@]}"; do
        if curl -s "${YARP_URL}${endpoint}" > /dev/null; then
            working_endpoints=$((working_endpoints + 1))
            echo -e "   ✅ ${endpoint}"
        else
            echo -e "   ❌ ${endpoint}"
        fi
    done
    
    if [[ $working_endpoints -eq ${#health_endpoints[@]} ]]; then
        echo -e "${GREEN}✅ All health endpoints working${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}⚠️  Some health endpoints not available (${working_endpoints}/${#health_endpoints[@]})${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))  # Don't fail for optional endpoints
    fi
}

# API functionality test
test_api_functionality() {
    echo -e "${YELLOW}🔧 Testing API functionality...${NC}"
    
    local tests=(
        "search:q=functionality:results"
        "auth:user=testuser:token"
        "search:q=health:results"
        "auth:user=health:token"
    )
    
    # Add C# script tests if available
    if [[ "$CSHARP_AVAILABLE" == "true" ]]; then
        tests+=(
            "csharp:service=functionality&data=test:script_type"
            "csharp:service=health:status"
        )
    fi
    
    local passed_api_tests=0
    
    for test in "${tests[@]}"; do
        IFS=':' read -r service params expected <<< "$test"
        
        local response=$(curl -s "${YARP_URL}/api/${service}?${params}")
        
        if echo "$response" | grep -q "$expected" && echo "$response" | grep -q "pid"; then
            echo -e "   ✅ ${service} API working"
            passed_api_tests=$((passed_api_tests + 1))
        else
            echo -e "   ❌ ${service} API failed"
        fi
    done
    
    if [[ $passed_api_tests -eq ${#tests[@]} ]]; then
        echo -e "${GREEN}✅ All API tests passed${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ API tests failed: ${passed_api_tests}/${#tests[@]} passed${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# System resource check
check_system_resources() {
    echo -e "${YELLOW}📊 System resource usage:${NC}"
    
    # Check CPU and memory usage of CGI processes
    local cgi_processes=$(pgrep -f "\.cgi" | wc -l)
    local python_processes=$(pgrep -f "python.*\.py" | wc -l)
    local csharp_processes=$(pgrep -f "dotnet-script.*\.csx" | wc -l)
    local yarp_processes=$(pgrep -f "dotnet.*CGIProxy" | wc -l)
    
    echo -e "   C CGI processes running: ${cgi_processes}"
    echo -e "   Python CGI processes running: ${python_processes}"
    echo -e "   C# script processes running: ${csharp_processes}"
    echo -e "   YARP processes running: ${yarp_processes}"
    
    # Check average response time
    if [[ $RESPONSE_COUNT -gt 0 ]]; then
        local avg_response_time=$((TOTAL_RESPONSE_TIME / RESPONSE_COUNT))
        echo -e "   Average response time: ${avg_response_time}ms"
    fi
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    # Kill any remaining background processes
    jobs -p | xargs -r kill 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT

# Main test execution
main() {
    echo -e "${BLUE}Starting stress tests...${NC}\n"
    
    check_system
    echo ""
    
    test_api_functionality
    echo ""
    
    test_load_balancing
    echo ""
    
    test_concurrency
    echo ""
    
    test_sustained_load
    echo ""
    
    test_health_monitoring
    echo ""
    
    check_system_resources
    echo ""
    
    # Final results
    echo "========================================"
    echo -e "${BLUE}📋 Test Results Summary${NC}"
    echo "========================================"
    
    local total_tests=$((PASSED_TESTS + FAILED_TESTS))
    local success_rate=$(( PASSED_TESTS * 100 / total_tests ))
    
    echo -e "Total tests: ${total_tests}"
    echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
    echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
    echo -e "Success rate: ${success_rate}%"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All tests passed! System is performing well under load.${NC}"
        exit 0
    else
        echo -e "\n${YELLOW}⚠️  Some tests failed. Check system configuration and resource usage.${NC}"
        exit 1
    fi
}

# Help function
show_help() {
    echo "CGI Process Pool Stress Test"
    echo ""
    echo "Tests C, Python, and C# script CGI services with comprehensive load testing."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -c, --concurrent N      Number of concurrent requests (default: $CONCURRENT_REQUESTS)"
    echo "  -t, --total N          Total number of requests (default: $TOTAL_REQUESTS)"
    echo "  -d, --duration N       Sustained load test duration in seconds (default: $TEST_DURATION)"
    echo "  -u, --url URL          Target URL (default: $YARP_URL)"
    echo ""
    echo "Tested Services:"
    echo "  • Search API (C)       - /api/search"
    echo "  • Auth API (C)         - /api/auth"
    echo "  • C# Script API        - /api/csharp (auto-detected)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run with default settings"
    echo "  $0 -c 100 -t 500       # Run with 100 concurrent requests, 500 total"
    echo "  $0 -d 60               # Run sustained load test for 60 seconds"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--concurrent)
            CONCURRENT_REQUESTS="$2"
            shift 2
            ;;
        -t|--total)
            TOTAL_REQUESTS="$2"
            shift 2
            ;;
        -d|--duration)
            TEST_DURATION="$2"
            shift 2
            ;;
        -u|--url)
            YARP_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main