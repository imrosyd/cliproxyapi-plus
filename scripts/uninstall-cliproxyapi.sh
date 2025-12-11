#!/bin/bash
#
# CLIProxyAPI-Plus Uninstaller for Linux/WSL2
#
# SYNOPSIS:
#   Completely removes CLIProxyAPI-Plus and all related files.
#   By default, preserves auth files and .factory/config.json.
#
# USAGE:
#   uninstall-cliproxyapi [OPTIONS]
#
# OPTIONS:
#   --all             Remove everything including auth files
#   --keep-auth       Keep OAuth tokens (default behavior)
#   --keep-droid      Keep Droid config (default behavior)
#   --force, -f       No confirmation prompt
#   -h, --help        Show this help message
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
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cli-proxy-api"
CLONE_DIR="$HOME/CLIProxyAPIPlus"
FACTORY_CONFIG="$HOME/.factory/config.json"

# Default options
REMOVE_ALL=false
KEEP_AUTH=true
KEEP_DROID=true
FORCE=false

# Functions
write_step() { echo -e "${CYAN}[*] $1${NC}"; }
write_success() { echo -e "${GREEN}[+] $1${NC}"; }
write_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
write_error() { echo -e "${RED}[-] $1${NC}"; }

show_help() {
    sed -n '2,18p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

get_size() {
    local path=$1
    if [ -d "$path" ]; then
        du -sh "$path" 2>/dev/null | cut -f1
    elif [ -f "$path" ]; then
        ls -lh "$path" 2>/dev/null | awk '{print $5}'
    else
        echo "N/A"
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all) REMOVE_ALL=true; KEEP_AUTH=false; KEEP_DROID=false; shift ;;
        --keep-auth) KEEP_AUTH=true; shift ;;
        --keep-droid) KEEP_DROID=true; shift ;;
        --force|-f) FORCE=true; shift ;;
        -h|--help) show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
done

echo -e "${RED}"
cat << 'EOF'
==========================================
  CLIProxyAPI-Plus Uninstaller
==========================================
EOF
echo -e "${NC}"

# Stop server if running
write_step "Checking for running server..."
PID_FILE="$CONFIG_DIR/server.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        write_warning "Stopping running server (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 1
        write_success "Server stopped"
    fi
fi

# Also check by process name
PIDS=$(pgrep -f "cliproxyapi-plus" 2>/dev/null || true)
if [ -n "$PIDS" ]; then
    write_warning "Stopping additional server processes..."
    echo "$PIDS" | xargs kill 2>/dev/null || true
    sleep 1
fi

# Scan installation
write_step "Scanning installation..."

declare -a TO_REMOVE
declare -a TO_KEEP

# Files to always remove
ALWAYS_REMOVE=(
    "$BIN_DIR/cliproxyapi-plus:Binary"
    "$BIN_DIR/cliproxyapi-plus.old:Binary backup"
    "$BIN_DIR/start-cliproxyapi:Start script"
    "$BIN_DIR/cliproxyapi-oauth:OAuth script"
    "$BIN_DIR/update-cliproxyapi:Update script"
    "$BIN_DIR/uninstall-cliproxyapi:Uninstall script"
    "$BIN_DIR/cp-start:Start alias"
    "$BIN_DIR/cp-login:Login alias"
    "$BIN_DIR/cp-status:Status alias"
    "$BIN_DIR/cp-update:Update alias"
    "$BIN_DIR/cp-uninstall:Uninstall alias"
    "$CLONE_DIR:Clone directory"
    "$CONFIG_DIR/config.yaml:Config file"
    "$CONFIG_DIR/logs:Logs directory"
    "$CONFIG_DIR/server.pid:PID file"
)

# Files to optionally remove
OPTIONAL_AUTH=(
    "$CONFIG_DIR/*.json:Auth files"
    "$CONFIG_DIR:Config directory"
)

OPTIONAL_DROID=(
    "$FACTORY_CONFIG:Droid config"
)

echo ""
echo -e "${YELLOW}Files to remove:${NC}"

for item in "${ALWAYS_REMOVE[@]}"; do
    path="${item%%:*}"
    name="${item##*:}"
    if [ -e "$path" ] || [ -d "$path" ]; then
        size=$(get_size "$path")
        echo "  [x] $name ($path) - $size"
        TO_REMOVE+=("$path")
    fi
done

if [ "$KEEP_AUTH" = false ]; then
    for item in "${OPTIONAL_AUTH[@]}"; do
        path="${item%%:*}"
        name="${item##*:}"
        # Handle glob pattern
        if [[ "$path" == *"*"* ]]; then
            for f in $path; do
                if [ -e "$f" ]; then
                    size=$(get_size "$f")
                    echo "  [x] $name ($f) - $size"
                    TO_REMOVE+=("$f")
                fi
            done
        elif [ -e "$path" ] || [ -d "$path" ]; then
            size=$(get_size "$path")
            echo "  [x] $name ($path) - $size"
            TO_REMOVE+=("$path")
        fi
    done
else
    echo ""
    echo -e "${GREEN}Files to keep (auth):${NC}"
    for item in "${OPTIONAL_AUTH[@]}"; do
        path="${item%%:*}"
        name="${item##*:}"
        if [[ "$path" == *"*"* ]]; then
            for f in $path; do
                if [ -e "$f" ]; then
                    echo "  [✓] $name ($f)"
                    TO_KEEP+=("$f")
                fi
            done
        elif [ -e "$path" ] || [ -d "$path" ]; then
            echo "  [✓] $name ($path)"
            TO_KEEP+=("$path")
        fi
    done
fi

if [ "$KEEP_DROID" = false ]; then
    for item in "${OPTIONAL_DROID[@]}"; do
        path="${item%%:*}"
        name="${item##*:}"
        if [ -e "$path" ]; then
            size=$(get_size "$path")
            echo "  [x] $name ($path) - $size"
            TO_REMOVE+=("$path")
        fi
    done
else
    echo ""
    echo -e "${GREEN}Files to keep (droid):${NC}"
    for item in "${OPTIONAL_DROID[@]}"; do
        path="${item%%:*}"
        name="${item##*:}"
        if [ -e "$path" ]; then
            echo "  [✓] $name ($path)"
            TO_KEEP+=("$path")
        fi
    done
fi

echo ""

if [ ${#TO_REMOVE[@]} -eq 0 ]; then
    write_success "Nothing to remove. CLIProxyAPI-Plus is not installed."
    exit 0
fi

# Confirmation
if [ "$FORCE" = false ]; then
    echo -e "${RED}WARNING: This action cannot be undone!${NC}"
    echo ""
    read -p "Are you sure you want to uninstall? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        write_success "Uninstall cancelled."
        exit 0
    fi
fi

# Perform removal
write_step "Removing files..."

for path in "${TO_REMOVE[@]}"; do
    if [ -d "$path" ]; then
        rm -rf "$path" 2>/dev/null && echo "    Removed directory: $path" || echo "    Failed to remove: $path"
    elif [ -f "$path" ]; then
        rm -f "$path" 2>/dev/null && echo "    Removed file: $path" || echo "    Failed to remove: $path"
    fi
done

# Clean up PATH from shell config
write_step "Cleaning up PATH configuration..."

for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [ -f "$rc_file" ]; then
        if grep -q "CLIProxyAPI-Plus" "$rc_file" 2>/dev/null; then
            # Remove the CLIProxyAPI-Plus lines
            sed -i '/# CLIProxyAPI-Plus/d' "$rc_file" 2>/dev/null || true
            sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' "$rc_file" 2>/dev/null || true
            echo "    Cleaned: $rc_file"
        fi
    fi
done

write_success "PATH configuration cleaned"

echo -e "${GREEN}"
cat << EOF

==========================================
  Uninstall Complete!
==========================================
EOF
echo -e "${NC}"

if [ ${#TO_KEEP[@]} -gt 0 ]; then
    echo "Preserved files:"
    for path in "${TO_KEEP[@]}"; do
        echo "  - $path"
    done
    echo ""
    echo "To remove auth files, run with --all flag:"
    echo "  uninstall-cliproxyapi --all"
    echo ""
fi

echo "Thank you for using CLIProxyAPI-Plus!"
echo ""
