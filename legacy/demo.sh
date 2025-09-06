#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}     CGI Process Pool Demo${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    
    if [ ! -z "$POOL_PID" ]; then
        kill $POOL_PID 2>/dev/null || true
        echo "   Stopped pool manager"
    fi
    
    if [ ! -z "$NGINX_PID" ]; then
        sudo nginx -s stop 2>/dev/null || true
        echo "   Stopped nginx"
    fi
    
    pkill -f "search.cgi" 2>/dev/null || true
    pkill -f "auth.cgi" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

trap cleanup EXIT

echo -e "${YELLOW}🔧 Building CGI processes...${NC}"
make clean 2>/dev/null || true
make all

if [ ! -f "search.cgi" ] || [ ! -f "auth.cgi" ]; then
    echo -e "${RED}❌ Build failed. Please check the Makefile.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

echo -e "${YELLOW}🚀 Starting pool manager...${NC}"
python3 pool_manager.py &
POOL_PID=$!

echo "   Waiting for pools to initialize..."
sleep 3

if ! kill -0 $POOL_PID 2>/dev/null; then
    echo -e "${RED}❌ Pool manager failed to start${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Pool manager running (PID: $POOL_PID)${NC}"
echo ""

if [ -f "/tmp/cgi_upstreams.conf" ]; then
    echo -e "${YELLOW}📋 Generated upstream configuration:${NC}"
    cat /tmp/cgi_upstreams.conf
    echo ""
fi

echo -e "${YELLOW}🌐 Starting nginx...${NC}"
echo "   Note: This may require sudo password"

sudo cp nginx.conf /tmp/nginx-cgi-demo.conf
sudo nginx -c /tmp/nginx-cgi-demo.conf 2>/dev/null || {
    echo -e "${RED}❌ Failed to start nginx. Is it already running?${NC}"
    echo "   Try: sudo nginx -s stop"
    exit 1
}

NGINX_PID=$(pgrep -n nginx)
echo -e "${GREEN}✓ Nginx running${NC}"
echo ""

sleep 2

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}     Running Tests${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}📡 Testing search endpoint:${NC}"
curl -s "http://localhost/api/search?q=test" | python3 -m json.tool || echo "Failed"
echo ""

echo -e "${YELLOW}🔐 Testing auth endpoint:${NC}"
curl -s "http://localhost/api/auth?user=john" | python3 -m json.tool || echo "Failed"
echo ""

echo -e "${YELLOW}📊 Testing pool status:${NC}"
curl -s "http://localhost/pool-status"
echo -e "\n"

echo -e "${YELLOW}🔥 Load testing (10 parallel requests):${NC}"
echo "   Sending requests..."

for i in {1..10}; do
    curl -s "http://localhost/api/search?q=load_test_$i" > /tmp/load_test_$i.json &
done
wait

echo "   Analyzing results..."
echo ""

PIDS=$(cat /tmp/load_test_*.json 2>/dev/null | grep -o '"pid": [0-9]*' | cut -d' ' -f2 | sort -u)
echo -e "   Unique PIDs that handled requests: ${GREEN}${PIDS}${NC}"

rm -f /tmp/load_test_*.json

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}     Demo Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "The system is still running. You can test it with:"
echo "  curl http://localhost/api/search?q=your_query"
echo "  curl http://localhost/api/auth?user=username"
echo ""
echo "Press Ctrl+C to stop all services"
echo ""

wait $POOL_PID