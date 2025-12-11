#!/bin/bash
#
# CLIProxyAPI-Plus Service Manager
# Install, uninstall, and manage systemd service
#

set -e

# Configuration
SERVICE_NAME="cliproxyapi-plus"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
USER_SERVICE_FILE="$USER_SERVICE_DIR/${SERVICE_NAME}.service"
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cli-proxy-api"
BINARY="$BIN_DIR/cliproxyapi-plus"
CONFIG="$CONFIG_DIR/config.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

write_step() { echo -e "\n${CYAN}[*] $1${NC}"; }
write_success() { echo -e "${GREEN}[+] $1${NC}"; }
write_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
write_error() { echo -e "${RED}[-] $1${NC}"; }

show_help() {
    cat << EOF
CLIProxyAPI-Plus Service Manager

Usage: $(basename "$0") [COMMAND]

Commands:
  install       Install and enable the service
  uninstall     Remove the service
  start         Start the service
  stop          Stop the service
  restart       Restart the service
  status        Show service status
  logs          Show service logs
  enable        Enable auto-start on boot
  disable       Disable auto-start on boot

Examples:
  $(basename "$0") install     # Install and start service
  $(basename "$0") status      # Check if running
  $(basename "$0") logs        # View logs

EOF
    exit 0
}

# Check if running in WSL
is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# Create user service (no sudo required)
create_user_service() {
    mkdir -p "$USER_SERVICE_DIR"
    
    cat > "$USER_SERVICE_FILE" << EOF
[Unit]
Description=CLIProxyAPI-Plus - Multi-Provider AI Proxy
After=network.target

[Service]
Type=simple
ExecStart=$BINARY --config $CONFIG
Restart=on-failure
RestartSec=5
Environment=HOME=$HOME
WorkingDirectory=$CONFIG_DIR

[Install]
WantedBy=default.target
EOF

    write_success "User service created: $USER_SERVICE_FILE"
}

# Install service
install_service() {
    write_step "Installing CLIProxyAPI-Plus service..."
    
    # Check prerequisites
    if [ ! -f "$BINARY" ]; then
        write_error "Binary not found: $BINARY"
        write_warning "Please install CLIProxyAPI-Plus first"
        exit 1
    fi
    
    if [ ! -f "$CONFIG" ]; then
        write_error "Config not found: $CONFIG"
        exit 1
    fi
    
    # Stop existing process if running
    if pgrep -f "cliproxyapi-plus" > /dev/null 2>&1; then
        write_warning "Stopping existing process..."
        pkill -f "cliproxyapi-plus" 2>/dev/null || true
        sleep 1
    fi
    
    if is_wsl; then
        write_warning "WSL detected - using user service (no systemd)"
        create_user_service
        
        # Create logs directory
        mkdir -p "$CONFIG_DIR/logs"
        
        # For WSL, we use a startup script instead
        STARTUP_SCRIPT="$BIN_DIR/cliproxyapi-startup.sh"
        cat > "$STARTUP_SCRIPT" << EOF
#!/bin/bash
# CLIProxyAPI-Plus Startup Script for WSL
# Starts both API server and GUI server in background

# Start API server
if ! pgrep -f "cliproxyapi-plus" > /dev/null 2>&1; then
    nohup $BINARY --config $CONFIG > $CONFIG_DIR/logs/api-server.log 2>&1 &
    echo \$! > $CONFIG_DIR/cliproxyapi.pid
fi

# Start GUI server
if ! pgrep -f "gui-server.py" > /dev/null 2>&1; then
    nohup python3 $BIN_DIR/gui-server.py --no-browser > $CONFIG_DIR/logs/gui-server.log 2>&1 &
    echo \$! > $CONFIG_DIR/gui-server.pid
fi
EOF
        chmod +x "$STARTUP_SCRIPT"
        
        # Add to .bashrc for auto-start
        if ! grep -q "cliproxyapi-startup" "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo "# CLIProxyAPI-Plus auto-start" >> "$HOME/.bashrc"
            echo "$STARTUP_SCRIPT > /dev/null 2>&1" >> "$HOME/.bashrc"
        fi
        
        write_success "WSL startup configured"
        write_success "Both API and GUI will auto-start when you open terminal"
        
        # Start now
        "$STARTUP_SCRIPT"
        sleep 2
        
        if pgrep -f "cliproxyapi-plus" > /dev/null 2>&1; then
            PID=$(pgrep -f "cliproxyapi-plus" | head -1)
            write_success "API Server started (PID: $PID)"
        else
            write_error "Failed to start API server"
        fi
        
        if pgrep -f "gui-server.py" > /dev/null 2>&1; then
            GUI_PID=$(pgrep -f "gui-server.py" | head -1)
            write_success "GUI Server started (PID: $GUI_PID) - http://localhost:8318"
        else
            write_warning "GUI Server not started (may need Python3)"
        fi
        
    else
        # Linux with systemd
        write_step "Creating systemd service..."
        
        sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=CLIProxyAPI-Plus - Multi-Provider AI Proxy
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$BINARY --config $CONFIG
Restart=on-failure
RestartSec=5
Environment=HOME=$HOME
WorkingDirectory=$CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF

        write_success "Service file created: $SERVICE_FILE"
        
        # Reload and enable
        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME"
        sudo systemctl start "$SERVICE_NAME"
        
        sleep 2
        
        if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
            write_success "Service installed and running"
            sudo systemctl status "$SERVICE_NAME" --no-pager
        else
            write_error "Service failed to start"
            sudo systemctl status "$SERVICE_NAME" --no-pager
            exit 1
        fi
    fi
    
    echo ""
    write_success "Installation complete!"
    echo ""
    echo "Commands:"
    echo "  cp-service status   - Check status"
    echo "  cp-service logs     - View logs"
    echo "  cp-service restart  - Restart service"
}

# Uninstall service
uninstall_service() {
    write_step "Uninstalling CLIProxyAPI-Plus service..."
    
    if is_wsl; then
        # Stop process
        pkill -f "cliproxyapi-plus" 2>/dev/null || true
        
        # Remove startup from .bashrc
        sed -i '/CLIProxyAPI-Plus auto-start/,/^fi$/d' "$HOME/.bashrc" 2>/dev/null || true
        sed -i '/cliproxyapi-startup/d' "$HOME/.bashrc" 2>/dev/null || true
        
        # Remove files
        rm -f "$BIN_DIR/cliproxyapi-startup.sh"
        rm -f "$USER_SERVICE_FILE"
        rm -f "$CONFIG_DIR/cliproxyapi.pid"
        
        write_success "WSL service removed"
    else
        if [ -f "$SERVICE_FILE" ]; then
            sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
            sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
            sudo rm -f "$SERVICE_FILE"
            sudo systemctl daemon-reload
            write_success "Systemd service removed"
        else
            write_warning "Service not installed"
        fi
    fi
}

# Start service
start_service() {
    if is_wsl; then
        if pgrep -f "cliproxyapi-plus" > /dev/null 2>&1; then
            write_warning "Service already running"
        else
            if [ -f "$BIN_DIR/cliproxyapi-startup.sh" ]; then
                "$BIN_DIR/cliproxyapi-startup.sh"
                sleep 1
                if pgrep -f "cliproxyapi-plus" > /dev/null 2>&1; then
                    PID=$(pgrep -f "cliproxyapi-plus" | head -1)
                    write_success "Service started (PID: $PID)"
                else
                    write_error "Failed to start"
                fi
            else
                write_error "Service not installed. Run: cp-service install"
            fi
        fi
    else
        sudo systemctl start "$SERVICE_NAME"
        write_success "Service started"
    fi
}

# Stop service
stop_service() {
    if is_wsl; then
        if pgrep -f "cliproxyapi-plus" > /dev/null 2>&1; then
            pkill -f "cliproxyapi-plus"
            write_success "API Server stopped"
        else
            write_warning "API Server not running"
        fi
        if pgrep -f "gui-server.py" > /dev/null 2>&1; then
            pkill -f "gui-server.py"
            write_success "GUI Server stopped"
        fi
    else
        sudo systemctl stop "$SERVICE_NAME"
        write_success "Service stopped"
    fi
}

# Restart service
restart_service() {
    stop_service
    sleep 1
    start_service
}

# Show status
show_status() {
    echo ""
    echo "=== CLIProxyAPI-Plus Service Status ==="
    echo ""
    
    if is_wsl; then
        # API Server status
        echo "API Server:"
        if pgrep -f "cliproxyapi-plus" > /dev/null 2>&1; then
            PID=$(pgrep -f "cliproxyapi-plus" | head -1)
            MEM=$(ps -o rss= -p "$PID" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
            echo -e "  Status: ${GREEN}RUNNING${NC}"
            echo "  PID: $PID"
            echo "  Memory: $MEM"
            echo "  Endpoint: http://localhost:8317/v1"
        else
            echo -e "  Status: ${RED}STOPPED${NC}"
        fi
        
        echo ""
        echo "GUI Server:"
        if pgrep -f "gui-server.py" > /dev/null 2>&1; then
            GUI_PID=$(pgrep -f "gui-server.py" | head -1)
            GUI_MEM=$(ps -o rss= -p "$GUI_PID" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
            echo -e "  Status: ${GREEN}RUNNING${NC}"
            echo "  PID: $GUI_PID"
            echo "  Memory: $GUI_MEM"
            echo "  URL: http://localhost:8318"
        else
            echo -e "  Status: ${RED}STOPPED${NC}"
        fi
    else
        sudo systemctl status "$SERVICE_NAME" --no-pager
    fi
    echo ""
}

# Show logs
show_logs() {
    if is_wsl; then
        LOG_FILE="$CONFIG_DIR/logs/service.log"
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            write_warning "No logs found"
        fi
    else
        sudo journalctl -u "$SERVICE_NAME" -f
    fi
}

# Enable auto-start
enable_service() {
    if is_wsl; then
        write_warning "WSL auto-start is handled via .bashrc"
    else
        sudo systemctl enable "$SERVICE_NAME"
        write_success "Auto-start enabled"
    fi
}

# Disable auto-start
disable_service() {
    if is_wsl; then
        sed -i '/CLIProxyAPI-Plus auto-start/,/^fi$/d' "$HOME/.bashrc" 2>/dev/null || true
        write_success "Auto-start disabled"
    else
        sudo systemctl disable "$SERVICE_NAME"
        write_success "Auto-start disabled"
    fi
}

# Main
case "${1:-}" in
    install)    install_service ;;
    uninstall)  uninstall_service ;;
    start)      start_service ;;
    stop)       stop_service ;;
    restart)    restart_service ;;
    status)     show_status ;;
    logs)       show_logs ;;
    enable)     enable_service ;;
    disable)    disable_service ;;
    -h|--help)  show_help ;;
    *)          show_help ;;
esac
