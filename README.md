# CLIProxyAPI-Plus

> Use multiple AI providers (Gemini, Claude, GPT, Qwen) through a single OpenAI-compatible API endpoint.

**One endpoint, many models.** Login to providers via OAuth, and access all models through `localhost:8317`.

---

## ✨ Features

- **Single API endpoint** - Access Claude, GPT, Gemini, Qwen through one URL
- **No API keys needed** - Uses OAuth from free tiers (Gemini CLI, GitHub Copilot)
- **Auto token import** - Automatically imports existing Gemini CLI credentials
- **OpenAI compatible** - Works with any OpenAI-compatible client
- **GUI Control Center** - Web-based management on port 8318
- **Multi-platform** - Windows, macOS, and Linux/WSL2 support

---

## 📦 Supported Providers

| Provider | Models | Free? |
|----------|--------|-------|
| **Gemini CLI** | gemini-3-pro, gemini-2.5-pro | ✅ Yes |
| **Antigravity** | claude-opus-4.5, claude-sonnet-4.5 | ✅ Yes |
| **GitHub Copilot** | claude-opus-4.5, gpt-5-mini | 💰 Subscription |
| **Codex** | gpt-5.1-codex-max | 💰 Subscription |
| **Claude** | claude-sonnet-4, claude-opus-4 | 💰 Subscription |
| **Qwen** | qwen3-coder-plus | 💰 Subscription |
| **iFlow** | glm-4.6, minimax-m2 | 💰 Subscription |
| **Kiro (AWS)** | kiro-claude-opus-4.5 | 💰 Subscription |

---

## 🚀 Quick Start

### 1. Install

**Linux/WSL2:**
```bash
curl -fsSL https://raw.githubusercontent.com/imrosyd/cliproxyapi-plus/main/scripts/install-cliproxyapi.sh | bash
source ~/.bashrc
```

**Windows (PowerShell as Admin):**
```powershell
irm https://raw.githubusercontent.com/imrosyd/cliproxyapi-plus/main/scripts/install-cliproxyapi.ps1 | iex
```

**macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/imrosyd/cliproxyapi-plus/main/scripts/install-cliproxyapi.sh | bash
source ~/.zshrc
```

### 2. Login to Providers

```bash
cp-login
```

Select providers from the interactive menu. If you have Gemini CLI installed, token will be auto-imported.

### 3. Start Server

```bash
cp-start --background
```

### 4. Use the API

```bash
curl http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-dummy" \
  -d '{"model":"gemini-3-pro","messages":[{"role":"user","content":"Hello!"}]}'
```

---

## 💻 Installation

### Linux / WSL2 (Ubuntu/Debian)

**Prerequisites:**
```bash
sudo apt update
sudo apt install -y git curl jq python3
```

**One-line install:**
```bash
curl -fsSL https://raw.githubusercontent.com/imrosyd/cliproxyapi-plus/main/scripts/install-cliproxyapi.sh | bash
source ~/.bashrc
```

**Manual install:**
```bash
git clone https://github.com/imrosyd/cliproxyapi-plus.git
cd cliproxyapi-plus
chmod +x scripts/*.sh
./scripts/install-cliproxyapi.sh
source ~/.bashrc
```

### Windows

**Prerequisites:**
- Windows 10/11
- PowerShell 5.1+ (run as Administrator)

**One-line install:**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/imrosyd/cliproxyapi-plus/main/scripts/install-cliproxyapi.ps1 | iex
```

**Manual install:**
```powershell
git clone https://github.com/imrosyd/cliproxyapi-plus.git
cd cliproxyapi-plus
.\scripts\install-cliproxyapi.ps1
```

### macOS

**Prerequisites:**
```bash
# Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git curl jq python3
```

**One-line install:**
```bash
curl -fsSL https://raw.githubusercontent.com/imrosyd/cliproxyapi-plus/main/scripts/install-cliproxyapi.sh | bash
source ~/.zshrc
```

**Manual install:**
```bash
git clone https://github.com/imrosyd/cliproxyapi-plus.git
cd cliproxyapi-plus
chmod +x scripts/*.sh
./scripts/install-cliproxyapi.sh
source ~/.zshrc
```

---

## 🔧 Commands

| Command | Description |
|---------|-------------|
| `cp-start` | Start/stop/restart server |
| `cp-login` | Login to OAuth providers |
| `cp-gui` | Open GUI control center |
| `cp-service` | Manage background service |
| `cp-update` | Update to latest version |
| `cp-uninstall` | Uninstall application |

### Examples

```bash
# Start server
cp-start --background

# Check status
cp-start --status

# Stop server
cp-start --stop

# Login (interactive menu)
cp-login

# Login specific provider
cp-login --gemini
cp-login --copilot
cp-login --all

# Check login status
cp-login --status

# Open GUI
cp-gui

# Update
cp-update

# Uninstall
cp-uninstall

# Install as background service (auto-start)
cp-service install

# Check service status
cp-service status

# View service logs
cp-service logs
```

---

## 🔄 Background Service

Run CLIProxyAPI-Plus as a background service with auto-start:

```bash
# Install and enable service
cp-service install

# Service commands
cp-service status     # Check if running
cp-service logs       # View logs (live)
cp-service restart    # Restart service
cp-service stop       # Stop service
cp-service start      # Start service
cp-service uninstall  # Remove service
```

**Note:** On WSL, auto-start is handled via `.bashrc`. On native Linux, systemd is used.

---

## 🔐 OAuth Login

### Gemini CLI (Auto-Import)

If you have Gemini CLI installed, the token is automatically imported:
```bash
cp-login --gemini
# Token imported from ~/.gemini/oauth_creds.json
```

### GitHub Copilot (Device Code)

Easiest login method:
```bash
cp-login --copilot
# Visit: https://github.com/login/device
# Enter the device code displayed
```

### Other Providers

```bash
cp-login
# Select provider from menu
# Browser opens for OAuth
# Authorize and wait for callback
```

### WSL2 Callback Issues

If OAuth callback fails in WSL2:
1. Copy the callback URL from browser address bar
2. In a new terminal: `curl "http://localhost:8085/oauth-callback?..."`

---

## 🌐 API Usage

### Endpoint
```
http://localhost:8317/v1/chat/completions
```

### Headers
```
Content-Type: application/json
Authorization: Bearer sk-dummy
```

### Example Request

```bash
curl http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-dummy" \
  -d '{
    "model": "gemini-3-pro",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ]
  }'
```

### Available Models

After login, check available models:
```bash
curl http://localhost:8317/v1/models -H "Authorization: Bearer sk-dummy"
```

---

## 🎮 GUI Control Center

Access the web-based control center:
```bash
cp-gui
# Opens http://localhost:8318
```

**Features:**
- Real-time server status with auto-refresh
- Start/Stop/Restart controls
- **Provider Toggle** - Enable/disable providers without logout
- **Factory Model Manager** - Sync models to Droid/Factory config
- OAuth login buttons for all providers
- Model list filtered by active providers
- Configuration editor with backup
- Activity logs

### Provider Toggle
Toggle providers ON/OFF to show/hide their models. Useful for focusing on specific AI providers without affecting login status.

### Factory Model Manager
Easily sync available models to your `~/.factory/config.json`:
- View all available models from active providers
- Add single or multiple models to Factory config
- Remove models or clear all
- Auto-generated display names

---

## 🔌 Integration

### Droid
Automatically configured during installation.

### Claude Code
```bash
export ANTHROPIC_BASE_URL="http://localhost:8317/v1"
export ANTHROPIC_API_KEY="sk-dummy"
claude
```

### Cursor
Settings → Models → OpenAI API:
- Base URL: `http://localhost:8317/v1`
- API Key: `sk-dummy`

### Continue (VS Code)
Edit `~/.continue/config.json`:
```json
{
  "models": [{
    "title": "CLIProxy",
    "provider": "openai",
    "model": "gemini-3-pro",
    "apiKey": "sk-dummy",
    "apiBase": "http://localhost:8317/v1"
  }]
}
```

### Python
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8317/v1",
    api_key="sk-dummy"
)

response = client.chat.completions.create(
    model="gemini-3-pro",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
```

---

## 📁 Project Structure

```
cliproxyapi-plus/
├── scripts/                        # Installation and runtime scripts
│   ├── install-cliproxyapi.sh      # Linux/macOS installer
│   ├── install-cliproxyapi.ps1     # Windows installer
│   ├── start-cliproxyapi.sh        # Server start/stop script
│   ├── start-cliproxyapi.ps1       # Windows server script
│   ├── cliproxyapi-oauth.sh        # OAuth login handler
│   ├── cliproxyapi-oauth.ps1       # Windows OAuth handler
│   ├── gui-cliproxyapi.sh          # GUI launcher
│   ├── gui-cliproxyapi.ps1         # Windows GUI launcher
│   ├── gui-server.py               # Python HTTP server for GUI
│   ├── service-cliproxyapi.sh      # Background service manager
│   ├── update-cliproxyapi.sh       # Update script
│   ├── update-cliproxyapi.ps1      # Windows update script
│   ├── uninstall-cliproxyapi.sh    # Uninstaller
│   ├── uninstall-cliproxyapi.ps1   # Windows uninstaller
│   └── wsl-browser.sh              # WSL browser helper
├── gui/
│   └── index.html                  # Web-based GUI control center
├── configs/
│   ├── config.yaml.example         # Configuration template
│   └── droid-config.json.example   # Droid/Factory integration example
├── docs/
│   └── BUG-server-side-browser.md  # Known bug documentation
├── README.md
└── LICENSE
```

---

## 📁 File Locations (Runtime)

### Linux/macOS
```
~/bin/cliproxyapi-plus          # Binary
~/bin/cp-login                  # Commands (symlinks)
~/.cli-proxy-api/config.yaml    # Configuration
~/.cli-proxy-api/*.json         # OAuth tokens
~/.cli-proxy-api/logs/          # Log files
```

### Windows
```
%USERPROFILE%\bin\cliproxyapi-plus.exe
%USERPROFILE%\.cli-proxy-api\config.yaml
%USERPROFILE%\.cli-proxy-api\*.json
```

---

## ⚙️ Configuration

Copy [`configs/config.yaml.example`](configs/config.yaml.example) to `~/.cli-proxy-api/config.yaml`:

```yaml
# Server port (default: 8317)
port: 8317

# Directory to store OAuth tokens
auth-dir: "~/.cli-proxy-api"

# API keys for authentication
api-keys:
  - "sk-dummy"

# Quota exceeded behavior
quota-exceeded:
  switch-project: true
  switch-preview-model: true

# Open OAuth URLs in incognito mode
incognito-browser: true

# Number of retry attempts
request-retry: 3

# Remote management
remote-management:
  allow-remote: false
  secret-key: ""
  disable-control-panel: false
```

---

## 🔍 Troubleshooting

### Command Not Found
```bash
source ~/.bashrc  # Linux
source ~/.zshrc   # macOS
# Or restart terminal
```

### Port Already in Use
```bash
cp-start --stop
# Or kill process on port
lsof -ti:8317 | xargs kill -9
```

### OAuth Callback Failed (WSL2)
```bash
# Copy callback URL from browser
curl "http://localhost:8085/oauth-callback?state=...&code=..."
```

### Token Not Saved
```bash
# Check if Gemini CLI token exists
ls ~/.gemini/oauth_creds.json

# Copy manually
cp ~/.gemini/oauth_creds.json ~/.cli-proxy-api/gemini-email.json
```

---

## 🐛 Known Bugs

### OAuth Browser Opens on Server (WSL/Tunnel)

**Issue:** When accessing GUI through a remote tunnel (e.g., Cloudflare tunnel), OAuth login opens the browser on the **server** instead of the client browser.

**Status:** Partially mitigated
- ✅ GUI returns `login_url` and `device_code` to client
- ✅ Frontend uses `window.open()` for client-side popup
- ❌ CLI binary still opens browser on server simultaneously

**Workaround:**
1. Ignore the browser that opens on the server
2. Use the popup from the GUI on your local browser
3. For device code flow (Copilot), copy the code from GUI modal

**Affected:** Remote/tunnel users only (local users unaffected)

See [`docs/BUG-server-side-browser.md`](docs/BUG-server-side-browser.md) for details.

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file.

---

## 🙏 Credits

- [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) - Original project

---

## ⭐ Star History

If you find this useful, please star the repo!
