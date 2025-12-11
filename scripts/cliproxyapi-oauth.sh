#!/bin/bash
# CLIProxyAPI-Plus OAuth Login Helper (Improved Version)
#
# SYNOPSIS:
#   Interactive script to login to all supported OAuth providers with
#   improved error handling, provider-specific instructions, and WSL2 support.
#
# USAGE:
#   cliproxyapi-oauth [OPTIONS]
#
# OPTIONS:
#   --all            Login to all providers (with guidance)
#   --gemini         Login to Gemini CLI
#   --antigravity    Login to Antigravity
#   --copilot        Login to GitHub Copilot
#   --codex          Login to Codex
#   --claude         Login to Claude
#   --qwen           Login to Qwen
#   --iflow          Login to iFlow
#   --kiro           Login to Kiro (AWS)
#   -h, --help       Show this help message

set -e

# Configuration
BINARY="$HOME/bin/cliproxyapi-plus"
CONFIG_FILE="$HOME/.cli-proxy-api/config.yaml"
TOKEN_DIR="$HOME/.cli-proxy-api"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Provider definitions: key="Display Name:cli-flag"
declare -A PROVIDERS
PROVIDERS["gemini"]="Gemini CLI:--login"
PROVIDERS["antigravity"]="Antigravity:--antigravity-login"
PROVIDERS["copilot"]="GitHub Copilot:--github-copilot-login"
PROVIDERS["codex"]="Codex:--codex-login"
PROVIDERS["claude"]="Claude:--claude-login"
PROVIDERS["qwen"]="Qwen:--qwen-login"
PROVIDERS["iflow"]="iFlow:--iflow-login"
PROVIDERS["kiro"]="Kiro (AWS):--kiro-aws-login"

# Provider order for menus
PROVIDER_ORDER=(gemini antigravity copilot codex claude qwen iflow kiro)

# Helper functions
write_step() {
    echo -e "${CYAN}[*]${NC} $1"
}

write_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

write_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

write_error() {
    echo -e "${RED}[-]${NC} $1"
}

write_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Auto-import Gemini CLI token if available
auto_import_gemini_token() {
    local GEMINI_CLI_TOKEN="$HOME/.gemini/oauth_creds.json"
    local GEMINI_ACCOUNTS="$HOME/.gemini/google_accounts.json"
    
    if [ -f "$GEMINI_CLI_TOKEN" ]; then
        # Get email from google_accounts.json
        local email=""
        if [ -f "$GEMINI_ACCOUNTS" ]; then
            email=$(cat "$GEMINI_ACCOUNTS" | grep -o '"active": "[^"]*"' | cut -d'"' -f4)
        fi
        
        if [ -z "$email" ]; then
            # Fallback: extract from id_token
            email=$(cat "$GEMINI_CLI_TOKEN" | grep -o '"email":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
        
        if [ -z "$email" ]; then
            email="user"
        fi
        
        local target_file="$TOKEN_DIR/gemini-${email}.json"
        
        if [ ! -f "$target_file" ]; then
            echo ""
            write_info "Gemini CLI token ditemukan di ~/.gemini/oauth_creds.json"
            read -p "Import token Gemini CLI? (Y/n): " confirm
            if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
                cp "$GEMINI_CLI_TOKEN" "$target_file"
                chmod 644 "$target_file"
                write_success "Token berhasil diimport ke $target_file"
                return 0
            fi
        else
            write_info "Gemini token sudah ada: $target_file"
            return 0
        fi
    fi
    return 1
}

# Show provider-specific instructions BEFORE login
show_provider_instructions() {
    local provider=$1
    
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    case "$provider" in
        gemini)
            echo -e "${YELLOW}📌 GEMINI CLI - Instruksi Penting:${NC}"
            echo ""
            echo "1. Browser akan terbuka untuk login Google"
            echo "2. Login dengan akun Google Anda"
            echo "3. Saat muncul list project, pilih:"
            echo -e "   ${GREEN}• Ketik: ALL${NC} (recommended)"
            echo -e "   ${GREEN}• ATAU pilih project dengan 'Gemini API'${NC}"
            echo ""
            echo -e "${RED}⚠️  JANGAN pilih project yang error sebelumnya!${NC}"
            echo ""
            echo "Jika ada error 'quota exceeded':"
            echo "  → Tunggu 1 jam dan coba lagi"
            echo "  → ATAU enable API di console.cloud.google.com"
            ;;
        antigravity)
            echo -e "${YELLOW}📌 ANTIGRAVITY - Instruksi Penting:${NC}"
            echo ""
            echo "1. Browser akan terbuka"
            echo "2. Login dengan akun Google yang SAMA dengan Gemini"
            echo "3. Authorize aplikasi"
            echo "4. JANGAN tutup browser sampai muncul 'success'"
            echo ""
            echo -e "${YELLOW}⚠️  WSL2 Issue: Jika callback gagal:${NC}"
            echo "  → Pastikan port 8085 tidak diblokir firewall"
            echo "  → Coba install: sudo apt install wslu"
            ;;
        copilot)
            echo -e "${YELLOW}📌 GITHUB COPILOT - Instruksi Penting:${NC}"
            echo ""
            echo "1. Akan muncul DEVICE CODE di terminal"
            echo "2. Buka: https://github.com/login/device"
            echo "3. Masukkan device code"
            echo "4. Authorize GitHub Copilot"
            echo ""
            echo -e "${GREEN}✓ Ini cara paling mudah (tidak perlu browser auto-open)${NC}"
            ;;
        codex)
            echo -e "${YELLOW}📌 CODEX - Instruksi Penting:${NC}"
            echo ""
            echo "1. Browser akan terbuka untuk login Codex"
            echo "2. Login dengan akun Codex Anda"
            echo "3. Authorize aplikasi"
            ;;
        claude)
            echo -e "${YELLOW}📌 CLAUDE - Instruksi Penting:${NC}"
            echo ""
            echo "1. Browser akan terbuka untuk login Anthropic"
            echo "2. Login dengan akun Claude Anda"
            echo "3. Memerlukan subscription aktif"
            ;;
        qwen)
            echo -e "${YELLOW}📌 QWEN - Instruksi Penting:${NC}"
            echo ""
            echo "1. Browser akan terbuka"
            echo "2. Login dengan akun Alibaba Cloud"
            echo "3. Authorize aplikasi"
            ;;
        iflow)
            echo -e "${YELLOW}📌 IFLOW - Instruksi Penting:${NC}"
            echo ""
            echo "1. Browser akan terbuka"
            echo "2. Login dengan akun iFlow"
            echo "3. Authorize aplikasi"
            ;;
        kiro)
            echo -e "${YELLOW}📌 KIRO (AWS) - Instruksi Penting:${NC}"
            echo ""
            echo "1. Browser akan terbuka untuk login AWS"
            echo "2. Login dengan akun AWS Anda"
            echo "3. Memerlukan subscription AWS"
            ;;
    esac
    
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check if provider is already logged in
check_provider_status() {
    local provider=$1
    local token_pattern=""
    
    case "$provider" in
        gemini) token_pattern="gemini*.json" ;;
        antigravity) token_pattern="antigravity*.json" ;;
        copilot) token_pattern="github-copilot*.json" ;;
        codex) token_pattern="codex*.json" ;;
        claude) token_pattern="claude*.json" ;;
        qwen) token_pattern="qwen*.json" ;;
        iflow) token_pattern="iflow*.json" ;;
        kiro) token_pattern="kiro*.json" ;;
    esac
    
    if ls "$TOKEN_DIR"/$token_pattern 1>/dev/null 2>&1; then
        return 0  # Logged in
    else
        return 1  # Not logged in
    fi
}

# Kill existing OAuth processes on port 8085
cleanup_port() {
    if lsof -ti:8085 >/dev/null 2>&1; then
        write_info "Cleaning up port 8085..."
        lsof -ti:8085 | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
}

# Run OAuth login for a provider
run_login() {
    local provider_key=$1
    local provider_info="${PROVIDERS[$provider_key]}"
    local name="${provider_info%%:*}"
    local flag="${provider_info##*:}"
    local skip_instructions=${2:-false}
    
    # Check if already logged in
    if check_provider_status "$provider_key"; then
        echo ""
        write_success "$name sudah login!"
        echo ""
        read -p "Login ulang? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            return 0
        fi
    fi
    
    # Cleanup port before starting
    cleanup_port
    
    # Show provider-specific instructions
    if [[ "$skip_instructions" != "true" ]]; then
        show_provider_instructions "$provider_key"
        read -p "Tekan ENTER untuk mulai login $name..."
    fi
    
    echo ""
    write_step "Logging in to $name..."
    echo -e "    ${CYAN}Command: $BINARY --config $CONFIG_FILE $flag${NC}"
    echo ""
    
    # Create a temporary browser wrapper to capture and display URL
    local FAKE_BROWSER=$(mktemp)
    cat > "$FAKE_BROWSER" << 'BROWSER_SCRIPT'
#!/bin/bash
URL="$1"

# Display the URL prominently
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "\033[1;36m🔗 OAuth URL:\033[0m"
echo ""
echo -e "\033[1;32m$URL\033[0m"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "\033[1;33m📋 Cara Login:\033[0m"
echo "  1. Copy URL di atas (triple-click untuk select all)"
echo "  2. Paste di browser Windows"
echo "  3. Login dan authorize"
echo ""

# Try to open in real browser
if command -v wslview &> /dev/null; then
    echo -e "\033[0;36m🌐 Opening browser automatically...\033[0m"
    wslview "$URL" &>/dev/null &
elif command -v xdg-open &> /dev/null; then
    echo -e "\033[0;36m🌐 Opening browser automatically...\033[0m"
    xdg-open "$URL" &>/dev/null &
else
    echo -e "\033[1;33m⚠️  Browser tidak auto-open. Copy URL manual.\033[0m"
fi

echo ""
BROWSER_SCRIPT
    
    chmod +x "$FAKE_BROWSER"
    
    # Run OAuth with our browser wrapper
    if BROWSER="$FAKE_BROWSER" "$BINARY" --config "$CONFIG_FILE" $flag; then
        # Verify token was saved
        if check_provider_status "$provider_key"; then
            write_success "$name login berhasil! Token tersimpan."
        else
            write_warning "$name login selesai, tapi token tidak tersimpan."
            echo -e "    ${YELLOW}Mungkin ada error saat OAuth. Coba lagi nanti.${NC}"
        fi
    else
        local exit_code=$?
        write_warning "$name login mungkin ada masalah (exit code: $exit_code)"
    fi
    
    # Cleanup
    rm -f "$FAKE_BROWSER"
}

# Show help
show_help() {
    sed -n '2,24p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Show current auth status
show_auth_status() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}   Status Login Providers${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    for provider in "${PROVIDER_ORDER[@]}"; do
        local info="${PROVIDERS[$provider]}"
        local name="${info%%:*}"
        
        if check_provider_status "$provider"; then
            echo -e "  ${GREEN}✓${NC} $name - ${GREEN}Logged In${NC}"
        else
            echo -e "  ${RED}✗${NC} $name - ${YELLOW}Not Logged In${NC}"
        fi
    done
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Interactive menu
show_menu() {
    clear
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║          CLIProxyAPI-Plus OAuth Login (Improved)               ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show current status
    echo -e "${CYAN}Status Login:${NC}"
    echo ""
    
    local idx=1
    for provider in "${PROVIDER_ORDER[@]}"; do
        local info="${PROVIDERS[$provider]}"
        local name="${info%%:*}"
        
        if check_provider_status "$provider"; then
            echo -e "  ${GREEN}$idx.${NC} $name ${GREEN}✓${NC}"
        else
            echo -e "  ${YELLOW}$idx.${NC} $name ${YELLOW}○${NC}"
        fi
        ((idx++))
    done
    
    echo ""
    echo -e "  ${CYAN}A.${NC} Login ke SEMUA yang belum login"
    echo -e "  ${CYAN}S.${NC} Tampilkan status"
    echo -e "  ${CYAN}R.${NC} Restart server"
    echo -e "  ${CYAN}Q.${NC} Keluar"
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Login all providers that are not yet logged in
login_all_pending() {
    echo ""
    write_info "Checking providers yang belum login..."
    echo ""
    
    local pending_count=0
    for provider in "${PROVIDER_ORDER[@]}"; do
        if ! check_provider_status "$provider"; then
            ((pending_count++))
        fi
    done
    
    if [ $pending_count -eq 0 ]; then
        write_success "Semua providers sudah login!"
        return 0
    fi
    
    echo "Found $pending_count provider(s) yang belum login."
    echo ""
    
    # Recommended order: copilot first (easiest), then others
    local recommended_order=(copilot codex iflow gemini antigravity claude qwen kiro)
    
    for provider in "${recommended_order[@]}"; do
        if ! check_provider_status "$provider"; then
            local info="${PROVIDERS[$provider]}"
            local name="${info%%:*}"
            
            echo ""
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}Next: $name${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            read -p "Login ke $name? (Y/n/skip): " confirm
            
            case "$confirm" in
                n|N)
                    write_info "Skipping $name"
                    continue
                    ;;
                skip|SKIP)
                    write_info "Skipping remaining providers"
                    break
                    ;;
                *)
                    run_login "$provider"
                    
                    # Verify after each login
                    if check_provider_status "$provider"; then
                        echo ""
                        write_success "$name login berhasil!"
                    else
                        echo ""
                        write_warning "$name login tidak berhasil. Lanjut ke provider berikutnya."
                    fi
                    
                    echo ""
                    read -p "Tekan ENTER untuk lanjut..."
                    ;;
            esac
        fi
    done
    
    echo ""
    write_info "Login session selesai."
    show_auth_status
}

# Restart server
restart_server() {
    write_step "Restarting server..."
    
    if command -v cp-start &> /dev/null; then
        cp-start --restart
    else
        "$HOME/bin/start-cliproxyapi" --restart
    fi
}

# Check binary exists
if [ ! -f "$BINARY" ]; then
    write_error "cliproxyapi-plus not found. Run install-cliproxyapi.sh first."
    exit 1
fi

# Parse arguments
if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        read -p "Pilih [1-8, A, S, R, Q]: " choice
        
        case "$choice" in
            [1-8])
                idx=$((choice - 1))
                provider="${PROVIDER_ORDER[$idx]}"
                run_login "$provider"
                read -p "Tekan ENTER untuk kembali ke menu..."
                ;;
            A|a)
                login_all_pending
                read -p "Tekan ENTER untuk kembali ke menu..."
                ;;
            S|s)
                show_auth_status
                read -p "Tekan ENTER untuk kembali ke menu..."
                ;;
            R|r)
                restart_server
                read -p "Tekan ENTER untuk kembali ke menu..."
                ;;
            Q|q)
                echo ""
                echo "Token files saved in: $TOKEN_DIR"
                ls -la "$TOKEN_DIR"/*.json 2>/dev/null | grep -v version || echo "No tokens found."
                echo ""
                exit 0
                ;;
            *)
                write_warning "Pilihan tidak valid"
                sleep 1
                ;;
        esac
    done
else
    # Command line mode
    case "$1" in
        --all)
            echo ""
            echo -e "${MAGENTA}=== CLIProxyAPI-Plus OAuth Login ===${NC}"
            login_all_pending
            ;;
        --gemini) auto_import_gemini_token || run_login "gemini" ;;
        --antigravity) run_login "antigravity" ;;
        --copilot) run_login "copilot" ;;
        --codex) run_login "codex" ;;
        --claude) run_login "claude" ;;
        --qwen) run_login "qwen" ;;
        --iflow) run_login "iflow" ;;
        --kiro) run_login "kiro" ;;
        -h|--help) show_help ;;
        --status) show_auth_status ;;
        *)
            write_error "Unknown option: $1"
            show_help
            ;;
    esac
    
    echo ""
    echo -e "${MAGENTA}==========================================${NC}"
    echo "  Auth files saved in: $TOKEN_DIR"
    echo -e "${MAGENTA}==========================================${NC}"
    echo ""
fi
