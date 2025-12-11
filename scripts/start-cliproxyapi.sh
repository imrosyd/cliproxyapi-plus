#!/bin/bash
#
# CLIProxyAPI-Plus Server Manager for Linux/WSL2
#
# SYNOPSIS:
#   Start, stop, and manage the CLIProxyAPI-Plus proxy server.
#
# USAGE:
#   start-cliproxyapi [OPTIONS]
#
# OPTIONS:
#   --background, -b    Start server in background
#   --status, -s        Check if server is running
#   --stop              Stop running server
#   --restart           Restart server
#   --logs, -l          View server logs
#   -h, --help          Show this help message
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
BINARY="$HOME/bin/cliproxyapi-plus"
CONFIG="$HOME/.cli-proxy-api/config.yaml"
LOG_DIR="$HOME/.cli-proxy-api/logs"
PID_FILE="$HOME/.cli-proxy-api/server.pid"
PORT=8317

# Functions
write_step() { echo -e "${CYAN}[*] $1${NC}"; }
write_success() { echo -e "${GREEN}[+] $1${NC}"; }
write_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
write_error() { echo -e "${RED}[-] $1${NC}"; }

show_help() {
    sed -n '2,18p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

get_server_pid() {
    # Check PID file first
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "$pid"
            return
        fi
    fi
    
    # Fallback: find process by name
    local pid=$(pgrep -f "cliproxyapi-plus" 2>/dev/null | head -1)
    if [ -z "$pid" ]; then
        pid=$(pgrep -f "cli-proxy-api" 2>/dev/null | head -1)
    fi
    echo "$pid"
}

test_port_in_use() {
    if command -v ss &> /dev/null; then
        ss -tuln | grep -q ":$PORT "
    elif command -v netstat &> /dev/null; then
        netstat -tuln | grep -q ":$PORT "
    elif command -v lsof &> /dev/null; then
        lsof -i ":$PORT" > /dev/null 2>&1
    else
        return 1
    fi
}

show_status() {
    echo -e "\n${MAGENTA}=== CLIProxyAPI-Plus Status ===${NC}"
    
    local pid=$(get_server_pid)
    
    if [ -n "$pid" ]; then
        write_success "Server is RUNNING"
        echo "  PID: $pid"
        
        # Get memory usage
        if command -v ps &> /dev/null; then
            local mem=$(ps -p "$pid" -o rss= 2>/dev/null)
            if [ -n "$mem" ]; then
                local mem_mb=$(echo "scale=1; $mem / 1024" | bc 2>/dev/null || echo "N/A")
                echo "  Memory: ${mem_mb} MB"
            fi
        fi
        
        # Get start time
        if command -v ps &> /dev/null; then
            local start_time=$(ps -p "$pid" -o lstart= 2>/dev/null)
            if [ -n "$start_time" ]; then
                echo "  Started: $start_time"
            fi
        fi
    else
        write_warning "Server is NOT running"
    fi
    
    echo ""
    if test_port_in_use; then
        echo -e "${GREEN}Port $PORT is in use${NC}"
    else
        echo -e "${YELLOW}Port $PORT is free${NC}"
    fi
    
    # Test endpoint
    echo ""
    if command -v curl &> /dev/null; then
        local response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/v1/models" --connect-timeout 2 2>/dev/null)
        if [ "$response" = "200" ] || [ "$response" = "401" ]; then
            write_success "API endpoint responding (HTTP $response)"
        else
            write_warning "API endpoint not responding"
        fi
    fi
    
    echo ""
}

stop_server() {
    local pid=$(get_server_pid)
    
    if [ -n "$pid" ]; then
        write_step "Stopping server (PID: $pid)..."
        kill "$pid" 2>/dev/null || true
        sleep 1
        
        # Force kill if still running
        if ps -p "$pid" > /dev/null 2>&1; then
            kill -9 "$pid" 2>/dev/null || true
            sleep 0.5
        fi
        
        # Remove PID file
        rm -f "$PID_FILE"
        
        if ! ps -p "$pid" > /dev/null 2>&1; then
            write_success "Server stopped"
        else
            write_error "Failed to stop server"
        fi
    else
        write_warning "Server is not running"
    fi
}

show_logs() {
    mkdir -p "$LOG_DIR"
    
    local latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    
    if [ -n "$latest_log" ]; then
        write_step "Showing logs from: $(basename "$latest_log")"
        echo -e "${CYAN}Press Ctrl+C to exit${NC}\n"
        tail -f "$latest_log"
    else
        write_warning "No log files found in $LOG_DIR"
        echo "Server may be running without file logging."
        echo "Start with: $BINARY --config $CONFIG"
    fi
}

start_server() {
    local in_background=$1
    
    # Check if already running
    local pid=$(get_server_pid)
    if [ -n "$pid" ]; then
        write_warning "Server is already running!"
        show_status
        return
    fi
    
    # Verify binary exists
    if [ ! -f "$BINARY" ]; then
        write_error "Binary not found: $BINARY"
        echo "Run install-cliproxyapi.sh first."
        exit 1
    fi
    
    # Verify config exists
    if [ ! -f "$CONFIG" ]; then
        write_error "Config not found: $CONFIG"
        echo "Run install-cliproxyapi.sh first."
        exit 1
    fi
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    if [ "$in_background" = true ]; then
        write_step "Starting server in background..."
        
        local log_file="$LOG_DIR/server-$(date +%Y%m%d-%H%M%S).log"
        nohup "$BINARY" --config "$CONFIG" > "$log_file" 2>&1 &
        local new_pid=$!
        
        echo "$new_pid" > "$PID_FILE"
        sleep 2
        
        if ps -p "$new_pid" > /dev/null 2>&1; then
            write_success "Server started in background (PID: $new_pid)"
            echo ""
            echo "Endpoint: http://localhost:$PORT/v1"
            echo "Logs:     $log_file"
            echo "To stop:  start-cliproxyapi --stop"
            echo "To status: start-cliproxyapi --status"
        else
            write_error "Server failed to start"
            echo "Check logs: $log_file"
            exit 1
        fi
    else
        write_step "Starting server in foreground..."
        echo "Press Ctrl+C to stop"
        echo ""
        exec "$BINARY" --config "$CONFIG"
    fi
}

# Parse arguments
ACTION="start"
BACKGROUND=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --background|-b) BACKGROUND=true; shift ;;
        --status|-s) ACTION="status"; shift ;;
        --stop) ACTION="stop"; shift ;;
        --restart) ACTION="restart"; shift ;;
        --logs|-l) ACTION="logs"; shift ;;
        -h|--help) show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
done

# Execute action
case $ACTION in
    status)
        show_status
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        sleep 1
        start_server "$BACKGROUND"
        ;;
    logs)
        show_logs
        ;;
    start)
        start_server "$BACKGROUND"
        ;;
esac
