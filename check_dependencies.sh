#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall status
ALL_DEPS_MET=true
MISSING_DEPS=()
WARNINGS=()

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   CGI Pool POC - Dependency Checker${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if a command exists
check_command() {
    local cmd=$1
    local name=$2
    local required=${3:-true}
    local install_hint=$4
    
    if command -v $cmd &> /dev/null; then
        local version=$(get_version $cmd)
        echo -e "${GREEN}✓${NC} $name: ${GREEN}Found${NC} $version"
        return 0
    else
        if [ "$required" = true ]; then
            echo -e "${RED}✗${NC} $name: ${RED}Not found${NC}"
            MISSING_DEPS+=("$name")
            if [ ! -z "$install_hint" ]; then
                echo -e "  ${YELLOW}→ Install: $install_hint${NC}"
            fi
            ALL_DEPS_MET=false
        else
            echo -e "${YELLOW}⚠${NC} $name: ${YELLOW}Not found (optional)${NC}"
            if [ ! -z "$install_hint" ]; then
                echo -e "  ${YELLOW}→ Install: $install_hint${NC}"
            fi
            WARNINGS+=("$name (optional)")
        fi
        return 1
    fi
}

# Function to get version info
get_version() {
    local cmd=$1
    case $cmd in
        gcc)
            echo "($(gcc --version 2>/dev/null | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1))"
            ;;
        python3)
            echo "($(python3 --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+'))"
            ;;
        nginx)
            echo "($(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+'))"
            ;;
        make)
            echo "($(make --version 2>/dev/null | head -n1 | grep -oP '\d+\.\d+'))"
            ;;
        curl)
            echo "($(curl --version 2>/dev/null | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1))"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to check Python module
check_python_module() {
    local module=$1
    local name=$2
    local install_name=${3:-$module}
    
    if python3 -c "import $module" &> /dev/null; then
        echo -e "${GREEN}✓${NC} Python module '$name': ${GREEN}Found${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} Python module '$name': ${RED}Not found${NC}"
        echo -e "  ${YELLOW}→ Install: pip3 install $install_name${NC}"
        MISSING_DEPS+=("Python: $name")
        ALL_DEPS_MET=false
        return 1
    fi
}

# Function to check file permissions
check_permission() {
    local file=$1
    local perm=$2
    local name=$3
    
    if [ -f "$file" ]; then
        if [ $perm "$file" ]; then
            echo -e "${GREEN}✓${NC} $name: ${GREEN}Correct permissions${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠${NC} $name: ${YELLOW}Permission issue${NC}"
            echo -e "  ${YELLOW}→ Fix: chmod +x $file${NC}"
            WARNINGS+=("$name permissions")
            return 1
        fi
    fi
    return 0
}

# Function to check port availability
check_port() {
    local port=$1
    
    if ! command -v lsof &> /dev/null && ! command -v ss &> /dev/null && ! command -v netstat &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} Cannot check port $port (no lsof/ss/netstat available)"
        return 0
    fi
    
    local in_use=false
    
    if command -v lsof &> /dev/null; then
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            in_use=true
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            in_use=true
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            in_use=true
        fi
    fi
    
    if [ "$in_use" = true ]; then
        echo -e "${YELLOW}⚠${NC} Port $port: ${YELLOW}Already in use${NC}"
        WARNINGS+=("Port $port in use")
        return 1
    else
        echo -e "${GREEN}✓${NC} Port $port: ${GREEN}Available${NC}"
        return 0
    fi
}

# Function to check nginx configuration
check_nginx_config() {
    if command -v nginx &> /dev/null; then
        if nginx -t -c $(pwd)/nginx.conf &> /dev/null; then
            echo -e "${GREEN}✓${NC} nginx.conf: ${GREEN}Valid syntax${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠${NC} nginx.conf: ${YELLOW}Syntax issues (may need sudo)${NC}"
            WARNINGS+=("nginx.conf syntax")
            return 1
        fi
    fi
    return 0
}

# Function to check system resources
check_system_resources() {
    echo -e "\n${BLUE}System Resources:${NC}"
    
    # Check available memory
    if command -v free &> /dev/null; then
        local mem_available=$(free -m | awk '/^Mem:/{print $7}')
        if [ "$mem_available" -lt 512 ]; then
            echo -e "${YELLOW}⚠${NC} Available memory: ${YELLOW}${mem_available}MB (low)${NC}"
            WARNINGS+=("Low memory")
        else
            echo -e "${GREEN}✓${NC} Available memory: ${GREEN}${mem_available}MB${NC}"
        fi
    fi
    
    # Check disk space
    local disk_available=$(df -m . | awk 'NR==2 {print $4}')
    if [ "$disk_available" -lt 100 ]; then
        echo -e "${YELLOW}⚠${NC} Available disk space: ${YELLOW}${disk_available}MB (low)${NC}"
        WARNINGS+=("Low disk space")
    else
        echo -e "${GREEN}✓${NC} Available disk space: ${GREEN}${disk_available}MB${NC}"
    fi
    
    # Check max file descriptors
    local max_fds=$(ulimit -n)
    if [ "$max_fds" -lt 1024 ]; then
        echo -e "${YELLOW}⚠${NC} Max file descriptors: ${YELLOW}${max_fds} (low)${NC}"
        echo -e "  ${YELLOW}→ Increase: ulimit -n 4096${NC}"
        WARNINGS+=("Low file descriptor limit")
    else
        echo -e "${GREEN}✓${NC} Max file descriptors: ${GREEN}${max_fds}${NC}"
    fi
}

# Main dependency checks
echo -e "${BLUE}Core Dependencies:${NC}"
check_command "gcc" "GCC Compiler" true "apt install gcc || yum install gcc"
check_command "make" "Make" true "apt install make || yum install make"
check_command "python3" "Python 3" true "apt install python3 || yum install python3"
check_command "nginx" "nginx" true "apt install nginx || yum install nginx"

echo -e "\n${BLUE}Python Dependencies:${NC}"
check_python_module "requests" "requests" "requests"

echo -e "\n${BLUE}Optional Tools:${NC}"
check_command "curl" "cURL" false "apt install curl || yum install curl"
check_command "jq" "jq (JSON processor)" false "apt install jq || yum install jq"
check_command "htop" "htop (Process monitor)" false "apt install htop || yum install htop"
check_command "git" "Git" false "apt install git || yum install git"

echo -e "\n${BLUE}File Permissions:${NC}"
check_permission "demo.sh" "-x" "demo.sh"
check_permission "pool_manager.py" "-x" "pool_manager.py"

echo -e "\n${BLUE}Port Availability:${NC}"
echo "Checking default ports (80, 8000-8010)..."
check_port 80
for port in {8000..8002}; do
    check_port $port
done

echo -e "\n${BLUE}Configuration Files:${NC}"
if [ -f "nginx.conf" ]; then
    echo -e "${GREEN}✓${NC} nginx.conf: ${GREEN}Found${NC}"
    check_nginx_config
else
    echo -e "${RED}✗${NC} nginx.conf: ${RED}Not found${NC}"
    ALL_DEPS_MET=false
fi

if [ -f "Makefile" ]; then
    echo -e "${GREEN}✓${NC} Makefile: ${GREEN}Found${NC}"
else
    echo -e "${RED}✗${NC} Makefile: ${RED}Not found${NC}"
    ALL_DEPS_MET=false
fi

# Check system resources
check_system_resources

# Final summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}              Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$ALL_DEPS_MET" = true ] && [ ${#WARNINGS[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All dependencies are satisfied!${NC}"
    echo -e "${GREEN}You can run: make run-demo${NC}"
    exit 0
elif [ "$ALL_DEPS_MET" = true ] && [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Core dependencies satisfied${NC}"
    echo -e "${YELLOW}⚠ Warnings (${#WARNINGS[@]}):${NC}"
    for warning in "${WARNINGS[@]}"; do
        echo -e "  ${YELLOW}• $warning${NC}"
    done
    echo -e "\n${GREEN}You can still run the demo, but may encounter issues.${NC}"
    exit 0
else
    echo -e "${RED}✗ Missing dependencies (${#MISSING_DEPS[@]}):${NC}"
    for dep in "${MISSING_DEPS[@]}"; do
        echo -e "  ${RED}• $dep${NC}"
    done
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}⚠ Warnings (${#WARNINGS[@]}):${NC}"
        for warning in "${WARNINGS[@]}"; do
            echo -e "  ${YELLOW}• $warning${NC}"
        done
    fi
    
    echo -e "\n${RED}Please install missing dependencies before running the demo.${NC}"
    
    # Offer quick install command for common distros
    echo -e "\n${BLUE}Quick install commands:${NC}"
    echo -e "${YELLOW}Ubuntu/Debian:${NC}"
    echo "  sudo apt update && sudo apt install -y gcc make python3 python3-pip nginx curl"
    echo "  pip3 install requests"
    echo ""
    echo -e "${YELLOW}RHEL/CentOS/Fedora:${NC}"
    echo "  sudo yum install -y gcc make python3 python3-pip nginx curl"
    echo "  pip3 install requests"
    echo ""
    echo -e "${YELLOW}macOS (with Homebrew):${NC}"
    echo "  brew install gcc make python3 nginx curl"
    echo "  pip3 install requests"
    
    exit 1
fi