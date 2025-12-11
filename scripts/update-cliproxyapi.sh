#!/bin/bash
#
# CLIProxyAPI-Plus Update Script for Linux/WSL2
#
# SYNOPSIS:
#   Updates CLIProxyAPI-Plus to the latest version.
#   - Pulls latest from repo OR downloads latest release
#   - Rebuilds binary OR extracts pre-built
#   - Preserves all config and auth files
#
# USAGE:
#   update-cliproxyapi [OPTIONS]
#
# OPTIONS:
#   --use-prebuilt    Download pre-built binary instead of building from source
#   --force           Force update even if already up to date
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
REPO_URL="https://github.com/router-for-me/CLIProxyAPIPlus.git"
RELEASE_API="https://api.github.com/repos/router-for-me/CLIProxyAPIPlus/releases/latest"
CLONE_DIR="$HOME/CLIProxyAPIPlus"
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cli-proxy-api"
BINARY_NAME="cliproxyapi-plus"

# Default options
USE_PREBUILT=false
FORCE=false

# Functions
write_step() { echo -e "\n${CYAN}[*] $1${NC}"; }
write_success() { echo -e "${GREEN}[+] $1${NC}"; }
write_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
write_error() { echo -e "${RED}[-] $1${NC}"; }

show_help() {
    sed -n '2,20p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "arm" ;;
        *) echo "amd64" ;;
    esac
}

detect_os() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    echo "$os"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --use-prebuilt) USE_PREBUILT=true; shift ;;
        --force) FORCE=true; shift ;;
        -h|--help) show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
done

echo -e "${MAGENTA}"
echo "=============================================="
echo "  CLIProxyAPI-Plus Updater"
echo "=============================================="
echo -e "${NC}"

# Check current version
write_step "Checking current installation..."
BINARY_PATH="$BIN_DIR/$BINARY_NAME"

if [ -f "$BINARY_PATH" ]; then
    CURRENT_DATE=$(stat -c %y "$BINARY_PATH" 2>/dev/null || stat -f %Sm "$BINARY_PATH" 2>/dev/null)
    echo "    Current binary: $CURRENT_DATE"
else
    write_warning "Binary not found. Run install-cliproxyapi.sh first."
    exit 1
fi

# Setup downloader
if command -v curl &> /dev/null; then
    DOWNLOADER="curl"
else
    DOWNLOADER="wget"
fi

# Check for latest release
write_step "Fetching latest release info..."
if [ "$DOWNLOADER" = "curl" ]; then
    RELEASE_JSON=$(curl -sL -H "User-Agent: Bash" "$RELEASE_API")
else
    RELEASE_JSON=$(wget -qO- --header="User-Agent: Bash" "$RELEASE_API")
fi

LATEST_VERSION=$(echo "$RELEASE_JSON" | jq -r '.tag_name // "unknown"')
PUBLISHED_AT=$(echo "$RELEASE_JSON" | jq -r '.published_at // "unknown"')
echo "    Latest version: $LATEST_VERSION"
echo "    Published: $PUBLISHED_AT"

# Stop server if running
PID_FILE="$CONFIG_DIR/server.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        write_step "Stopping running server..."
        kill "$PID" 2>/dev/null || true
        sleep 1
        write_success "Server stopped"
    fi
fi

OS=$(detect_os)
ARCH=$(detect_arch)

# Determine update method
if [ "$USE_PREBUILT" = false ] && [ -d "$CLONE_DIR" ] && [ -f "$CLONE_DIR/go.mod" ]; then
    write_step "Updating from source..."
    
    cd "$CLONE_DIR"
    
    # Fetch and check for updates
    echo "    Fetching latest changes..."
    git fetch origin main 2>/dev/null || git fetch origin master 2>/dev/null
    
    LOCAL_HASH=$(git rev-parse HEAD)
    REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)
    
    if [ "$LOCAL_HASH" = "$REMOTE_HASH" ] && [ "$FORCE" = false ]; then
        write_success "Already up to date!"
        exit 0
    fi
    
    echo "    Pulling latest changes..."
    git pull origin main --rebase 2>/dev/null || git pull origin master --rebase 2>/dev/null || {
        write_warning "Git pull failed, trying reset..."
        git fetch origin main 2>/dev/null || git fetch origin master
        git reset --hard origin/main 2>/dev/null || git reset --hard origin/master
    }
    
    echo "    Building binary..."
    
    # Backup current binary
    if [ -f "$BINARY_PATH" ]; then
        cp "$BINARY_PATH" "${BINARY_PATH}.old"
    fi
    
    go build -o "$BIN_DIR/$BINARY_NAME" ./cmd/server
    chmod +x "$BIN_DIR/$BINARY_NAME"
    
    write_success "Binary rebuilt from source"
    
else
    write_step "Downloading latest pre-built binary..."
    
    ASSET_NAME="${OS}_${ARCH}"
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r ".assets[] | select(.name | contains(\"$ASSET_NAME\")) | .browser_download_url" | head -1)
    
    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | contains("linux_amd64")) | .browser_download_url' | head -1)
    fi
    
    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        write_error "Could not find binary for $OS/$ARCH in latest release"
        exit 1
    fi
    
    ASSET_FILENAME=$(basename "$DOWNLOAD_URL")
    TEMP_DIR=$(mktemp -d)
    DOWNLOAD_PATH="$TEMP_DIR/$ASSET_FILENAME"
    
    echo "    Downloading $ASSET_FILENAME..."
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -sL -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL"
    else
        wget -q -O "$DOWNLOAD_PATH" "$DOWNLOAD_URL"
    fi
    
    # Backup current binary
    if [ -f "$BINARY_PATH" ]; then
        cp "$BINARY_PATH" "${BINARY_PATH}.old"
    fi
    
    echo "    Extracting..."
    cd "$TEMP_DIR"
    
    if [[ "$ASSET_FILENAME" == *.tar.gz ]]; then
        tar -xzf "$DOWNLOAD_PATH"
    elif [[ "$ASSET_FILENAME" == *.zip ]]; then
        unzip -q "$DOWNLOAD_PATH"
    fi
    
    # Find the binary in extracted files
    EXTRACTED_BINARY=$(find "$TEMP_DIR" -type f -name "cliproxyapi*" ! -name "*.tar.gz" ! -name "*.zip" | head -1)
    if [ -z "$EXTRACTED_BINARY" ]; then
        EXTRACTED_BINARY=$(find "$TEMP_DIR" -type f -name "cli-proxy-api*" ! -name "*.tar.gz" ! -name "*.zip" | head -1)
    fi
    
    if [ -n "$EXTRACTED_BINARY" ]; then
        chmod +x "$EXTRACTED_BINARY"
        cp "$EXTRACTED_BINARY" "$BIN_DIR/$BINARY_NAME"
        write_success "Binary updated from pre-built release"
    else
        write_error "Could not find binary in extracted archive"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
fi

# Verify new binary
write_step "Verifying update..."
if [ -f "$BINARY_PATH" ]; then
    FILE_SIZE=$(stat -c%s "$BINARY_PATH" 2>/dev/null || stat -f%z "$BINARY_PATH" 2>/dev/null)
    if [ "$FILE_SIZE" -gt 1048576 ]; then
        write_success "Update verified ($(echo "scale=1; $FILE_SIZE / 1048576" | bc 2>/dev/null || echo "OK") MB)"
    else
        write_error "Binary seems corrupted"
        if [ -f "${BINARY_PATH}.old" ]; then
            write_warning "Restoring backup..."
            mv "${BINARY_PATH}.old" "$BINARY_PATH"
        fi
        exit 1
    fi
fi

# Remove backup
rm -f "${BINARY_PATH}.old"

echo -e "${GREEN}"
cat << EOF

==============================================
  Update Complete!
==============================================
  Version: $LATEST_VERSION
  Binary:  $BINARY_PATH

  To restart server: start-cliproxyapi --restart
==============================================
EOF
echo -e "${NC}"
