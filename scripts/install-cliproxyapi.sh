#!/bin/bash
#
# CLIProxyAPI-Plus Installation Script for Linux/WSL2
# 
# SYNOPSIS:
#   Complete one-click installer that sets up CLIProxyAPI-Plus for Factory Droid.
#   - Downloads pre-built binary or builds from source
#   - Configures ~/.cli-proxy-api/config.yaml
#   - Updates ~/.factory/config.json with custom models
#   - Provides OAuth login prompts
#
# USAGE:
#   ./install-cliproxyapi.sh [OPTIONS]
#
# OPTIONS:
#   --use-prebuilt    Download pre-built binary instead of building from source
#   --skip-oauth      Skip OAuth setup instructions
#   --force           Force reinstall (overwrite existing files)
#   -h, --help        Show this help message
#
# REQUIREMENTS:
#   - git
#   - curl or wget
#   - go 1.21+ (optional, for building from source)
#   - jq (will be installed if missing)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/router-for-me/CLIProxyAPIPlus.git"
RELEASE_API="https://api.github.com/repos/router-for-me/CLIProxyAPIPlus/releases/latest"
CLONE_DIR="$HOME/CLIProxyAPIPlus"
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cli-proxy-api"
FACTORY_DIR="$HOME/.factory"
BINARY_NAME="cliproxyapi-plus"

# Default options
USE_PREBUILT=false
SKIP_OAUTH=false
FORCE=false

# Functions
write_step() { echo -e "\n${CYAN}[*] $1${NC}"; }
write_success() { echo -e "${GREEN}[+] $1${NC}"; }
write_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
write_error() { echo -e "${RED}[-] $1${NC}"; }

show_help() {
    sed -n '2,25p' "$0" | sed 's/^# //' | sed 's/^#//'
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
        --skip-oauth) SKIP_OAUTH=true; shift ;;
        --force) FORCE=true; shift ;;
        -h|--help) show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
done

echo -e "${MAGENTA}"
echo "=============================================="
echo "  CLIProxyAPI-Plus Installer for Linux/WSL2"
echo "=============================================="
echo -e "${NC}"

# Check prerequisites
write_step "Checking prerequisites..."

# Check git
if ! command -v git &> /dev/null; then
    write_error "Git is not installed. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y git
    elif command -v yum &> /dev/null; then
        sudo yum install -y git
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm git
    else
        write_error "Could not install git. Please install it manually."
        exit 1
    fi
fi
write_success "Git found: $(git --version)"

# Check curl or wget
if command -v curl &> /dev/null; then
    DOWNLOADER="curl"
    write_success "curl found"
elif command -v wget &> /dev/null; then
    DOWNLOADER="wget"
    write_success "wget found"
else
    write_error "Neither curl nor wget found. Installing curl..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y curl
        DOWNLOADER="curl"
    else
        write_error "Could not install curl. Please install it manually."
        exit 1
    fi
fi

# Check jq (for JSON parsing)
if ! command -v jq &> /dev/null; then
    write_warning "jq not found. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm jq
    elif command -v brew &> /dev/null; then
        brew install jq
    else
        write_error "Could not install jq. Please install it manually."
        exit 1
    fi
fi
write_success "jq found"

# Check Go (only if not using prebuilt)
if [ "$USE_PREBUILT" = false ]; then
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version)
        write_success "Go found: $GO_VERSION"
    else
        write_warning "Go is not installed. Switching to prebuilt binary mode."
        USE_PREBUILT=true
    fi
fi

# Create directories
write_step "Creating directories..."
mkdir -p "$BIN_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$FACTORY_DIR"
write_success "Directories ready"

# Detect OS and architecture
OS=$(detect_os)
ARCH=$(detect_arch)
write_success "Detected: $OS/$ARCH"

# Install binary
if [ "$USE_PREBUILT" = true ]; then
    write_step "Downloading pre-built binary from GitHub Releases..."
    
    # Get latest release info
    if [ "$DOWNLOADER" = "curl" ]; then
        RELEASE_JSON=$(curl -sL -H "User-Agent: Bash" "$RELEASE_API")
    else
        RELEASE_JSON=$(wget -qO- --header="User-Agent: Bash" "$RELEASE_API")
    fi
    
    # Find the right asset for this platform
    ASSET_NAME="${OS}_${ARCH}"
    
    # Try to find matching asset (tar.gz or zip)
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r ".assets[] | select(.name | contains(\"$ASSET_NAME\")) | .browser_download_url" | head -1)
    
    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        # Fallback: try linux_amd64
        DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | contains("linux_amd64")) | .browser_download_url' | head -1)
    fi
    
    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        write_error "Could not find binary for $OS/$ARCH in latest release"
        write_warning "Available assets:"
        echo "$RELEASE_JSON" | jq -r '.assets[].name'
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
    
    echo "    Extracting..."
    cd "$TEMP_DIR"
    
    if [[ "$ASSET_FILENAME" == *.tar.gz ]]; then
        tar -xzf "$DOWNLOAD_PATH"
    elif [[ "$ASSET_FILENAME" == *.zip ]]; then
        unzip -q "$DOWNLOAD_PATH"
    else
        # Assume it's a raw binary
        chmod +x "$DOWNLOAD_PATH"
        cp "$DOWNLOAD_PATH" "$BIN_DIR/$BINARY_NAME"
    fi
    
    # Find the binary in extracted files
    EXTRACTED_BINARY=$(find "$TEMP_DIR" -type f -name "cliproxyapi*" ! -name "*.tar.gz" ! -name "*.zip" | head -1)
    if [ -z "$EXTRACTED_BINARY" ]; then
        EXTRACTED_BINARY=$(find "$TEMP_DIR" -type f -name "cli-proxy-api*" ! -name "*.tar.gz" ! -name "*.zip" | head -1)
    fi
    
    if [ -n "$EXTRACTED_BINARY" ]; then
        chmod +x "$EXTRACTED_BINARY"
        cp "$EXTRACTED_BINARY" "$BIN_DIR/$BINARY_NAME"
        write_success "Binary installed: $BIN_DIR/$BINARY_NAME"
    else
        write_error "Could not find binary in extracted archive"
        ls -la "$TEMP_DIR"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
else
    write_step "Building from source..."
    
    # Clone or update repo
    if [ -d "$CLONE_DIR" ]; then
        if [ "$FORCE" = true ] || [ ! -f "$CLONE_DIR/go.mod" ]; then
            echo "    Removing existing clone..."
            rm -rf "$CLONE_DIR"
        fi
    fi
    
    if [ ! -d "$CLONE_DIR" ]; then
        echo "    Cloning repository..."
        git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
    fi
    
    echo "    Building binary..."
    cd "$CLONE_DIR"
    go build -o "$BIN_DIR/$BINARY_NAME" ./cmd/server
    
    write_success "Binary built: $BIN_DIR/$BINARY_NAME"
fi

# Create config.yaml
write_step "Configuring ~/.cli-proxy-api/config.yaml..."

CONFIG_PATH="$CONFIG_DIR/config.yaml"
if [ -f "$CONFIG_PATH" ] && [ "$FORCE" = false ]; then
    write_warning "config.yaml already exists, skipping (use --force to overwrite)"
else
    cat > "$CONFIG_PATH" << 'EOF'
port: 8317
auth-dir: "~/.cli-proxy-api"
api-keys:
  - "sk-dummy"
quota-exceeded:
  switch-project: true
  switch-preview-model: true
incognito-browser: true
request-retry: 3
remote-management:
  allow-remote: false
  secret-key: ""
  disable-control-panel: false
EOF
    write_success "config.yaml created"
fi

# Update .factory/config.json
write_step "Updating ~/.factory/config.json..."

FACTORY_CONFIG_PATH="$FACTORY_DIR/config.json"
cat > "$FACTORY_CONFIG_PATH" << 'EOF'
{
  "custom_models": [
    {"model_display_name": "Claude Opus 4.5 Thinking [Antigravity]", "model": "gemini-claude-opus-4-5-thinking", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Claude Sonnet 4.5 Thinking [Antigravity]", "model": "gemini-claude-sonnet-4-5-thinking", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Claude Sonnet 4.5 [Antigravity]", "model": "gemini-claude-sonnet-4-5", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Gemini 3 Pro [Antigravity]", "model": "gemini-3-pro-preview", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "GPT OSS 120B [Antigravity]", "model": "gpt-oss-120b-medium", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Claude Opus 4.5 [Copilot]", "model": "claude-opus-4.5", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "GPT-5 Mini [Copilot]", "model": "gpt-5-mini", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Grok Code Fast 1 [Copilot]", "model": "grok-code-fast-1", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Gemini 2.5 Pro [Gemini]", "model": "gemini-2.5-pro", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Gemini 3 Pro Preview [Gemini]", "model": "gemini-3-pro-preview", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "GPT-5.1 Codex Max [Codex]", "model": "gpt-5.1-codex-max", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Qwen3 Coder Plus [Qwen]", "model": "qwen3-coder-plus", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "GLM 4.6 [iFlow]", "model": "glm-4.6", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Minimax M2 [iFlow]", "model": "minimax-m2", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Claude Opus 4.5 [Kiro]", "model": "kiro-claude-opus-4.5", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Claude Sonnet 4.5 [Kiro]", "model": "kiro-claude-sonnet-4.5", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Claude Sonnet 4 [Kiro]", "model": "kiro-claude-sonnet-4", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"},
    {"model_display_name": "Claude Haiku 4.5 [Kiro]", "model": "kiro-claude-haiku-4.5", "base_url": "http://localhost:8317/v1", "api_key": "sk-dummy", "provider": "openai"}
  ]
}
EOF
write_success "config.json updated with 18 custom models"

# Verify installation
write_step "Verifying installation..."
if [ -f "$BIN_DIR/$BINARY_NAME" ]; then
    FILE_SIZE=$(stat -f%z "$BIN_DIR/$BINARY_NAME" 2>/dev/null || stat -c%s "$BIN_DIR/$BINARY_NAME" 2>/dev/null)
    FILE_SIZE_MB=$(echo "scale=1; $FILE_SIZE / 1048576" | bc 2>/dev/null || echo "N/A")
    if [ "$FILE_SIZE" -gt 1048576 ]; then
        write_success "Binary verification passed (${FILE_SIZE_MB} MB)"
    else
        write_error "Binary seems corrupted (too small: $FILE_SIZE bytes)"
        exit 1
    fi
else
    write_error "Binary not found at $BIN_DIR/$BINARY_NAME"
    exit 1
fi

# Make binary executable
chmod +x "$BIN_DIR/$BINARY_NAME"

# Copy helper scripts to bin directory
write_step "Installing helper scripts..."
# Get absolute path to script directory
INSTALL_SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(dirname "$INSTALL_SCRIPT_PATH")"

for script in start-cliproxyapi.sh cliproxyapi-oauth.sh update-cliproxyapi.sh uninstall-cliproxyapi.sh; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        cp "$SCRIPT_DIR/$script" "$BIN_DIR/${script%.sh}"
        chmod +x "$BIN_DIR/${script%.sh}"
        write_success "Installed: $BIN_DIR/${script%.sh}"
    else
        write_warning "Script not found: $SCRIPT_DIR/$script"
    fi
done

# Create short aliases (cp-* commands)
write_step "Creating command aliases..."
ln -sf "$BIN_DIR/start-cliproxyapi" "$BIN_DIR/cp-start" 2>/dev/null
ln -sf "$BIN_DIR/cliproxyapi-oauth" "$BIN_DIR/cp-login" 2>/dev/null
ln -sf "$BIN_DIR/update-cliproxyapi" "$BIN_DIR/cp-update" 2>/dev/null
ln -sf "$BIN_DIR/uninstall-cliproxyapi" "$BIN_DIR/cp-uninstall" 2>/dev/null

# Create cp-status as wrapper for cp-start --status
cat > "$BIN_DIR/cp-status" << 'EOFSTATUS'
#!/bin/bash
exec "$(dirname "$0")/start-cliproxyapi" --status "$@"
EOFSTATUS
chmod +x "$BIN_DIR/cp-status"

write_success "Created: cp-start, cp-login, cp-status, cp-update, cp-uninstall"

# Add ~/bin to PATH if not already
write_step "Configuring PATH..."

PATH_ADDED=false
SHELL_RC=""

# Detect shell config file
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_RC="$HOME/.bash_profile"
fi

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    # Add to shell RC file
    if [ -n "$SHELL_RC" ]; then
        # Check if already added (avoid duplicates)
        if ! grep -q 'CLIProxyAPI-Plus' "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# CLIProxyAPI-Plus" >> "$SHELL_RC"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
            write_success "Added $BIN_DIR to PATH in $SHELL_RC"
        fi
        PATH_ADDED=true
    fi
    
    # Also add to .profile for login shells (important for WSL)
    if [ -f "$HOME/.profile" ]; then
        if ! grep -q 'CLIProxyAPI-Plus' "$HOME/.profile" 2>/dev/null; then
            echo "" >> "$HOME/.profile"
            echo "# CLIProxyAPI-Plus" >> "$HOME/.profile"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
            write_success "Added $BIN_DIR to PATH in ~/.profile"
        fi
    fi
    
    export PATH="$BIN_DIR:$PATH"
else
    write_success "$BIN_DIR already in PATH"
fi

# OAuth login prompts
if [ "$SKIP_OAUTH" = false ]; then
    echo -e "${YELLOW}"
    cat << EOF

==============================================
  OAuth Login Setup (Optional)
==============================================
Run these commands to login to each provider:

  # Gemini CLI
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --login

  # Antigravity
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --antigravity-login

  # GitHub Copilot
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --github-copilot-login

  # Codex
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --codex-login

  # Claude
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --claude-login

  # Qwen
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --qwen-login

  # iFlow
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --iflow-login

  # Kiro (AWS)
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --kiro-aws-login

==============================================
EOF
    echo -e "${NC}"
fi

echo -e "${GREEN}"
cat << EOF

==============================================
  Installation Complete!
==============================================
EOF
echo -e "${NC}"

cat << EOF
Installed Files:
  Binary:   $BIN_DIR/$BINARY_NAME
  Config:   $CONFIG_DIR/config.yaml
  Droid:    $FACTORY_DIR/config.json

Available Commands (after PATH refresh):
  cp-start              Start/stop/restart server
  cp-login              Login to OAuth providers
  cp-status             Check server status
  cp-update             Update to latest version
  cp-uninstall          Remove everything

  Legacy commands (still available):
  start-cliproxyapi, cliproxyapi-oauth, update-cliproxyapi, uninstall-cliproxyapi

Quick Start:
  1. Refresh PATH:    source $SHELL_RC
  2. Start server:    cp-start --background
  3. Login OAuth:     cp-login --all
  4. Check status:    cp-status
  5. Use with Droid:  droid (select cliproxyapi-plus/* model)
EOF

if [ "$PATH_ADDED" = true ]; then
    echo -e "${YELLOW}"
    cat << EOF

NOTE: PATH telah ditambahkan ke $SHELL_RC
EOF
    echo -e "${NC}"
fi

# Auto-start server
write_step "Starting CLIProxyAPI server..."
export PATH="$BIN_DIR:$PATH"

# Try to start server in background
if [ -f "$BIN_DIR/start-cliproxyapi" ]; then
    "$BIN_DIR/start-cliproxyapi" --background 2>/dev/null &
    sleep 2
    
    # Check if server started
    if curl -s http://localhost:8317/health >/dev/null 2>&1 || pgrep -f "$BINARY_NAME" >/dev/null 2>&1; then
        write_success "Server started on http://localhost:8317"
    else
        write_warning "Server may have failed to start. Run: cp-start --background"
    fi
else
    write_warning "start-cliproxyapi not found. Run: cp-start --background"
fi

echo -e "${GREEN}"
cat << EOF

==============================================
  Installation Complete!
==============================================
Server running on: http://localhost:8317
GUI available at:  http://localhost:8318

Next Steps:
  1. Login to providers: cp-login
  2. Check status:       cp-start --status
  3. Use with Droid:     Select cliproxyapi-plus model

Available Commands:
  cp-start    Start/stop/restart server
  cp-login    Login to OAuth providers
  cp-status   Check server status
  cp-update   Update to latest version
==============================================
EOF
echo -e "${NC}"
