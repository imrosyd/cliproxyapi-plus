#!/usr/bin/env python3
"""
CLIProxyAPI-Plus GUI Management Server (Linux/macOS)
Provides HTTP server for GUI and API endpoints for server control.
"""

import os
import sys
import json
import subprocess
import signal
import time
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from pathlib import Path
from datetime import datetime
import threading

# Configuration
DEFAULT_PORT = 8318
API_PORT = 8317
SCRIPT_VERSION = "1.1.0"

# Paths
HOME = Path.home()
BIN_DIR = HOME / "bin"
CONFIG_DIR = HOME / ".cli-proxy-api"
BINARY = BIN_DIR / "cliproxyapi-plus"
CONFIG_FILE = CONFIG_DIR / "config.yaml"
LOG_DIR = CONFIG_DIR / "logs"
VERSION_FILE = CONFIG_DIR / "version.json"
FACTORY_CONFIG = HOME / ".factory" / "config.json"

# Find GUI path
SCRIPT_DIR = Path(__file__).resolve().parent
GUI_PATH = SCRIPT_DIR.parent / "gui" / "index.html"

# Try alternative locations if not found
if not GUI_PATH.exists():
    # Check if we're in ~/bin (symlink or copy)
    possible_paths = [
        HOME / "CLIProxyAPIPlus" / "gui" / "index.html",
        HOME / "cliproxyapi-plus" / "gui" / "index.html",
        HOME / "project" / "cliproxyapi-plus" / "gui" / "index.html",
        Path("/home/imron/project/cliproxyapi-plus/gui/index.html"),
    ]
    for path in possible_paths:
        if path.exists():
            GUI_PATH = path
            break

PROCESS_NAMES = ["cliproxyapi-plus", "cli-proxy-api"]

# GitHub repos
GITHUB_REPO = "imrosyd/cliproxyapi-plus"
UPSTREAM_REPO = "router-for-me/CLIProxyAPIPlus"


def log(msg):
    """Print timestamped log message"""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")


def get_server_process():
    """Find running CLIProxyAPI server process"""
    try:
        import psutil
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                name = proc.info['name']
                if any(pname in name for pname in PROCESS_NAMES):
                    return proc
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
    except ImportError:
        # Fallback to pgrep if psutil not available
        for pname in PROCESS_NAMES:
            try:
                result = subprocess.run(['pgrep', '-f', pname], 
                                      capture_output=True, text=True)
                if result.returncode == 0 and result.stdout.strip():
                    pid = int(result.stdout.strip().split()[0])
                    return {'pid': pid, 'name': pname}
            except:
                continue
    return None


def get_server_status():
    """Get current server status"""
    proc = get_server_process()
    
    if proc:
        try:
            import psutil
            if isinstance(proc, dict):
                # Fallback mode
                return {
                    'running': True,
                    'pid': proc['pid'],
                    'memory': None,
                    'startTime': None,
                    'port': API_PORT,
                    'endpoint': f'http://localhost:{API_PORT}/v1'
                }
            else:
                # psutil mode
                return {
                    'running': True,
                    'pid': proc.pid,
                    'memory': round(proc.memory_info().rss / 1024 / 1024, 1),
                    'startTime': datetime.fromtimestamp(proc.create_time()).isoformat(),
                    'port': API_PORT,
                    'endpoint': f'http://localhost:{API_PORT}/v1'
                }
        except:
            return {
                'running': True,
                'pid': proc.get('pid') if isinstance(proc, dict) else proc.pid,
                'memory': None,
                'startTime': None,
                'port': API_PORT,
                'endpoint': f'http://localhost:{API_PORT}/v1'
            }
    
    return {
        'running': False,
        'pid': None,
        'memory': None,
        'startTime': None,
        'port': API_PORT,
        'endpoint': f'http://localhost:{API_PORT}/v1'
    }


def start_api_server():
    """Start the CLIProxyAPI server"""
    proc = get_server_process()
    if proc:
        pid = proc.pid if hasattr(proc, 'pid') else proc.get('pid')
        return {'success': False, 'error': f'Server already running (PID: {pid})'}
    
    if not BINARY.exists():
        return {'success': False, 'error': f'Binary not found: {BINARY}'}
    
    if not CONFIG_FILE.exists():
        return {'success': False, 'error': f'Config not found: {CONFIG_FILE}'}
    
    # Ensure log directory exists
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    
    try:
        stdout_log = LOG_DIR / "server-stdout.log"
        stderr_log = LOG_DIR / "server-stderr.log"
        
        # Clear old logs
        stdout_log.write_text("")
        stderr_log.write_text("")
        
        # Start server in background
        with open(stdout_log, 'w') as out, open(stderr_log, 'w') as err:
            proc = subprocess.Popen(
                [str(BINARY), '--config', str(CONFIG_FILE)],
                stdout=out,
                stderr=err,
                cwd=str(CONFIG_DIR),
                start_new_session=True
            )
        
        # Wait a bit to check if it started successfully
        time.sleep(0.5)
        
        if proc.poll() is None:
            return {'success': True, 'pid': proc.pid, 'message': 'Server started'}
        else:
            # Read error from logs
            error_msg = "Server exited immediately"
            try:
                stderr_content = stderr_log.read_text().strip()
                stdout_content = stdout_log.read_text().strip()
                combined = (stdout_content + stderr_content).strip()
                if combined:
                    error_msg += f": {combined}"
            except:
                pass
            return {'success': False, 'error': error_msg}
    
    except Exception as e:
        return {'success': False, 'error': str(e)}


def stop_api_server():
    """Stop the CLIProxyAPI server"""
    proc = get_server_process()
    if not proc:
        return {'success': False, 'error': 'Server not running'}
    
    try:
        pid = proc.pid if hasattr(proc, 'pid') else proc.get('pid')
        os.kill(pid, signal.SIGTERM)
        time.sleep(0.3)
        return {'success': True, 'message': 'Server stopped'}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def restart_api_server():
    """Restart the CLIProxyAPI server"""
    stop_api_server()
    time.sleep(0.5)
    return start_api_server()


def start_oauth_login(provider):
    """Start OAuth login for a provider"""
    flags = {
        'gemini': '--login',
        'copilot': '--github-copilot-login',
        'antigravity': '--antigravity-login',
        'codex': '--codex-login',
        'claude': '--claude-login',
        'qwen': '--qwen-login',
        'iflow': '--iflow-login',
        'kiro': '--kiro-aws-login'
    }
    
    provider_lower = provider.lower()
    if provider_lower not in flags:
        return {'success': False, 'error': f'Unknown provider: {provider}'}
    
    flag = flags[provider_lower]
    
    try:
        # Ensure log directory exists
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        oauth_log = LOG_DIR / f"oauth-{provider_lower}.log"
        
        # Start OAuth in a new process with proper environment
        # Use subprocess with stdout/stderr to files but inherit environment
        # to allow browser opening
        env = os.environ.copy()
        
        # Ensure DISPLAY is set for X11 applications (browser)
        if 'DISPLAY' not in env:
            env['DISPLAY'] = ':0'
        
        # For WSL, also try to set BROWSER if not set
        if 'BROWSER' not in env:
            # Check for common browsers
            browsers = ['xdg-open', 'sensible-browser', 'firefox', 'google-chrome', 'chromium-browser']
            for browser in browsers:
                try:
                    result = subprocess.run(['which', browser], capture_output=True, text=True)
                    if result.returncode == 0:
                        env['BROWSER'] = result.stdout.strip()
                        break
                except:
                    continue
        
        with open(oauth_log, 'w') as log_file:
            subprocess.Popen(
                [str(BINARY), '--config', str(CONFIG_FILE), flag],
                stdout=log_file,
                stderr=log_file,
                env=env,
                cwd=str(CONFIG_DIR),
                start_new_session=False  # Keep in same session to allow browser access
            )
        
        log(f"OAuth login started for {provider} (log: {oauth_log})")
        return {'success': True, 'message': f'OAuth login started for {provider}'}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def get_auth_status():
    """Check which providers are logged in"""
    auth_patterns = {
        'gemini': 'gemini-*.json',
        'copilot': 'github-copilot-*.json',
        'antigravity': 'antigravity-*.json',
        'codex': 'codex-*.json',
        'claude': 'claude-*.json',
        'qwen': 'qwen-*.json',
        'iflow': 'iflow-*.json',
        'kiro': 'kiro-*.json'
    }
    
    status = {}
    for provider, pattern in auth_patterns.items():
        files = list(CONFIG_DIR.glob(pattern))
        status[provider] = len(files) > 0
    
    return status


def get_model_provider(model_id):
    """Identify which provider a model belongs to based on its ID"""
    model_lower = model_id.lower()
    
    # Provider prefixes mapping
    if any(x in model_lower for x in ['gemini', 'tstars', 'learnlm']):
        return 'gemini'
    elif any(x in model_lower for x in ['copilot', 'gpt-4', 'gpt-5', 'o1-', 'o3-', 'o4-']):
        return 'copilot'
    elif 'gemini-claude' in model_lower or model_lower.startswith('antigravity'):
        return 'antigravity'
    elif any(x in model_lower for x in ['codex', 'code-davinci']):
        return 'codex'
    elif any(x in model_lower for x in ['claude', 'sonnet', 'opus', 'haiku']):
        return 'claude'
    elif any(x in model_lower for x in ['qwen', 'qwq']):
        return 'qwen'
    elif any(x in model_lower for x in ['iflow', 'deepseek', 'grok', 'raptor']):
        return 'iflow'
    elif any(x in model_lower for x in ['kiro', 'kiro-claude', 'kimi']):
        return 'kiro'
    
    # Default - try to match by first part of model name
    return None


def get_available_models():
    """Get available models from running server, filtered by provider toggles"""
    proc = get_server_process()
    if not proc:
        return {'success': False, 'error': 'Server not running', 'models': []}
    
    try:
        import urllib.request
        req = urllib.request.Request(
            f'http://localhost:{API_PORT}/v1/models',
            headers={'Authorization': 'Bearer sk-dummy'}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read())
            all_models = [m['id'] for m in data.get('data', [])]
            
            # Get provider toggle states
            toggles = get_provider_toggles()
            
            # Filter models based on provider toggles
            filtered_models = []
            for model in all_models:
                provider = get_model_provider(model)
                # Include model if:
                # 1. Provider not identified (unknown provider)
                # 2. Provider is enabled (toggles.get(provider) is not False)
                if provider is None or toggles.get(provider, True):
                    filtered_models.append(model)
            
            return {'success': True, 'models': filtered_models, 'total': len(all_models)}
    except Exception as e:
        return {'success': False, 'error': str(e), 'models': []}


def get_config_content():
    """Get config.yaml content"""
    if not CONFIG_FILE.exists():
        return {'success': False, 'error': f'Config file not found: {CONFIG_FILE}', 'content': ''}
    
    try:
        content = CONFIG_FILE.read_text()
        return {'success': True, 'content': content}
    except Exception as e:
        return {'success': False, 'error': str(e), 'content': ''}


def set_config_content(content):
    """Update config.yaml content"""
    try:
        # Create backup
        backup_path = CONFIG_FILE.with_suffix('.yaml.bak')
        if CONFIG_FILE.exists():
            backup_path.write_text(CONFIG_FILE.read_text())
        
        # Write new content
        CONFIG_FILE.write_text(content)
        return {'success': True, 'message': 'Config saved'}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def get_request_stats():
    """Get request statistics (if available)"""
    proc = get_server_process()
    if proc:
        try:
            import urllib.request
            req = urllib.request.Request(f'http://localhost:{API_PORT}/stats')
            with urllib.request.urlopen(req, timeout=2) as response:
                data = json.loads(response.read())
                return {
                    'total': data.get('total_requests', 0),
                    'success': data.get('successful_requests', 0),
                    'errors': data.get('failed_requests', 0),
                    'successRate': round((data.get('successful_requests', 0) / max(data.get('total_requests', 1), 1)) * 100, 1),
                    'avgLatency': data.get('avg_latency_ms', 0),
                    'lastReset': data.get('start_time', datetime.now().isoformat()),
                    'available': True
                }
        except:
            pass
    
    return {
        'total': 0,
        'success': 0,
        'errors': 0,
        'successRate': 0,
        'avgLatency': 0,
        'lastReset': datetime.now().isoformat(),
        'available': False,
        'message': 'Stats not available - CLIProxyAPI doesn\'t expose request metrics'
    }


def get_factory_config():
    """Read ~/.factory/config.json"""
    factory_path = Path.home() / '.factory' / 'config.json'
    if factory_path.exists():
        try:
            return json.loads(factory_path.read_text())
        except:
            pass
    return {'custom_models': []}


def save_factory_config(config):
    """Save ~/.factory/config.json"""
    factory_path = Path.home() / '.factory' / 'config.json'
    factory_path.parent.mkdir(parents=True, exist_ok=True)
    factory_path.write_text(json.dumps(config, indent=2))


def add_factory_models(data):
    """Add models to factory config"""
    try:
        models = data.get('models', [])
        display_names = data.get('displayNames', {})
        
        if not models:
            return {'success': False, 'error': 'No models specified'}
        
        config = get_factory_config()
        existing_ids = {m.get('model') for m in config.get('custom_models', [])}
        
        added = []
        for model_id in models:
            if model_id not in existing_ids:
                display_name = display_names.get(model_id, model_id)
                config['custom_models'].append({
                    'model_display_name': display_name,
                    'model': model_id,
                    'base_url': 'http://localhost:8317/v1',
                    'api_key': 'sk-dummy',
                    'provider': 'openai'
                })
                added.append(model_id)
        
        save_factory_config(config)
        return {'success': True, 'added': added}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def remove_factory_models(data):
    """Remove models from factory config"""
    try:
        if data.get('all'):
            save_factory_config({'custom_models': []})
            return {'success': True, 'removed': ['all']}
        
        models = data.get('models', [])
        if not models:
            return {'success': False, 'error': 'No models specified'}
        
        config = get_factory_config()
        models_set = set(models)
        
        original_count = len(config.get('custom_models', []))
        config['custom_models'] = [m for m in config.get('custom_models', []) if m.get('model') not in models_set]
        removed_count = original_count - len(config['custom_models'])
        
        save_factory_config(config)
        return {'success': True, 'removed': models}
    except Exception as e:
        return {'success': False, 'error': str(e)}


# Provider toggles file
PROVIDER_TOGGLES_FILE = CONFIG_DIR / "provider-toggles.json"


def get_provider_toggles():
    """Get provider toggle states"""
    if PROVIDER_TOGGLES_FILE.exists():
        try:
            return json.loads(PROVIDER_TOGGLES_FILE.read_text())
        except:
            pass
    return {}


def set_provider_toggle(data):
    """Set provider toggle state"""
    try:
        provider = data.get('provider')
        enabled = data.get('enabled', True)
        
        if not provider:
            return {'success': False, 'error': 'Provider not specified'}
        
        toggles = get_provider_toggles()
        toggles[provider] = enabled
        
        PROVIDER_TOGGLES_FILE.write_text(json.dumps(toggles, indent=2))
        log(f"Provider {provider} {'enabled' if enabled else 'disabled'}")
        
        return {'success': True, 'provider': provider, 'enabled': enabled}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def get_local_version():
    """Get local version info"""
    if VERSION_FILE.exists():
        try:
            data = json.loads(VERSION_FILE.read_text())
            if 'commitSha' not in data:
                data['commitSha'] = 'unknown'
            return data
        except:
            pass
    
    # Create default version file
    default_version = {
        'scripts': SCRIPT_VERSION,
        'commitSha': 'unknown',
        'commitDate': None,
        'lastCheck': None
    }
    VERSION_FILE.write_text(json.dumps(default_version, indent=2))
    return default_version


def get_update_info():
    """Check for updates"""
    local = get_local_version()
    
    result = {
        'currentVersion': local['scripts'],
        'currentCommit': local['commitSha'],
        'latestCommit': None,
        'latestCommitDate': None,
        'latestCommitMessage': '',
        'hasUpdate': False,
        'downloadUrl': f'https://github.com/{GITHUB_REPO}/archive/refs/heads/main.zip',
        'repoUrl': f'https://github.com/{GITHUB_REPO}',
        'error': None
    }
    
    try:
        import urllib.request
        api_url = f'https://api.github.com/repos/{GITHUB_REPO}/commits/main'
        req = urllib.request.Request(api_url, headers={'User-Agent': 'CLIProxyAPI-Plus-Updater'})
        
        with urllib.request.urlopen(req, timeout=10) as response:
            commit = json.loads(response.read())
            
            result['latestCommit'] = commit['sha'][:7]
            result['latestCommitDate'] = commit['commit']['author']['date']
            result['latestCommitMessage'] = commit['commit']['message'].split('\n')[0]
            
            if local['commitSha'] == 'unknown':
                result['hasUpdate'] = True
            else:
                result['hasUpdate'] = local['commitSha'] != result['latestCommit']
            
            # Update last check time
            local['lastCheck'] = datetime.now().isoformat()
            VERSION_FILE.write_text(json.dumps(local, indent=2))
    
    except Exception as e:
        result['error'] = str(e)
    
    return result


def install_update():
    """Install update from GitHub"""
    try:
        import urllib.request
        import zipfile
        import shutil
        import tempfile
        
        # Get update info
        update_info = get_update_info()
        if update_info.get('error'):
            return {'success': False, 'error': f'Failed to get update info: {update_info["error"]}'}
        
        # Stop server if running
        proc = get_server_process()
        was_running = proc is not None
        if was_running:
            stop_api_server()
            time.sleep(1)
        
        # Download to temp
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            zip_file = temp_path / "update.zip"
            
            log(f"Downloading update from {update_info['downloadUrl']}")
            urllib.request.urlretrieve(update_info['downloadUrl'], zip_file)
            
            # Extract
            log("Extracting update...")
            with zipfile.ZipFile(zip_file, 'r') as zip_ref:
                zip_ref.extractall(temp_path)
            
            # Find extracted folder
            extracted_folders = [d for d in temp_path.iterdir() if d.is_dir()]
            if not extracted_folders:
                return {'success': False, 'error': 'No folder found in archive'}
            
            extracted_folder = extracted_folders[0]
            
            # Copy scripts
            scripts_source = extracted_folder / "scripts"
            if scripts_source.exists():
                for item in scripts_source.iterdir():
                    dest = BIN_DIR / item.name
                    if item.is_file():
                        shutil.copy2(item, dest)
                        dest.chmod(0o755)
            
            # Copy GUI
            gui_source = extracted_folder / "gui"
            gui_dest = GUI_PATH.parent
            if gui_source.exists():
                gui_dest.mkdir(parents=True, exist_ok=True)
                for item in gui_source.iterdir():
                    if item.is_file():
                        shutil.copy2(item, gui_dest / item.name)
            
            # Update version file
            local = get_local_version()
            local['commitSha'] = update_info['latestCommit']
            local['commitDate'] = update_info['latestCommitDate']
            VERSION_FILE.write_text(json.dumps(local, indent=2))
        
        # Restart server if it was running
        if was_running:
            start_api_server()
        
        return {
            'success': True,
            'message': 'Update installed successfully',
            'newCommit': update_info['latestCommit'],
            'commitMessage': update_info['latestCommitMessage'],
            'needsRestart': True
        }
    
    except Exception as e:
        return {'success': False, 'error': str(e)}


class GUIRequestHandler(BaseHTTPRequestHandler):
    """HTTP request handler for GUI and API"""
    
    def log_message(self, format, *args):
        """Override to use custom logging"""
        log(f"{self.command} {args[0]}")
    
    def send_json(self, data, status=200):
        """Send JSON response"""
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def send_html(self, html_path):
        """Send HTML file"""
        if not html_path.exists():
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'File not found')
            return
        
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(html_path.read_bytes())
    
    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def do_GET(self):
        """Handle GET requests"""
        path = urlparse(self.path).path
        
        if path == '/':
            self.send_html(GUI_PATH)
        elif path == '/api/status':
            self.send_json(get_server_status())
        elif path == '/api/auth-status':
            self.send_json(get_auth_status())
        elif path == '/api/models':
            self.send_json(get_available_models())
        elif path == '/api/config':
            self.send_json(get_config_content())
        elif path == '/api/stats':
            self.send_json(get_request_stats())
        elif path == '/api/update-info':
            self.send_json(get_update_info())
        elif path == '/api/factory-config':
            self.send_json(get_factory_config())
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def do_POST(self):
        """Handle POST requests"""
        path = urlparse(self.path).path
        
        # Read request body
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode() if content_length > 0 else '{}'
        
        try:
            data = json.loads(body) if body else {}
        except:
            data = {}
        
        if path == '/api/start':
            self.send_json(start_api_server())
        elif path == '/api/stop':
            self.send_json(stop_api_server())
        elif path == '/api/restart':
            self.send_json(restart_api_server())
        elif path.startswith('/api/oauth/'):
            provider = path.split('/')[-1]
            self.send_json(start_oauth_login(provider))
        elif path == '/api/config':
            content = data.get('content', '')
            self.send_json(set_config_content(content))
        elif path == '/api/update':
            self.send_json(install_update())
        elif path == '/api/factory-config/add':
            self.send_json(add_factory_models(data))
        elif path == '/api/factory-config/remove':
            self.send_json(remove_factory_models(data))
        elif path == '/api/provider-toggle':
            self.send_json(set_provider_toggle(data))
        else:
            self.send_json({'error': 'Not found'}, 404)


def main():
    parser = argparse.ArgumentParser(description='CLIProxyAPI+ GUI Management Server')
    parser.add_argument('-p', '--port', type=int, default=DEFAULT_PORT, help='Port to listen on')
    parser.add_argument('-n', '--no-browser', action='store_true', help='Don\'t open browser')
    args = parser.parse_args()
    
    # Check if GUI exists
    if not GUI_PATH.exists():
        print(f"[-] GUI not found at: {GUI_PATH}")
        sys.exit(1)
    
    # Create HTTP server
    server = HTTPServer(('localhost', args.port), GUIRequestHandler)
    
    print("\n" + "="*44)
    print("  CLIProxyAPI+ Control Center")
    print("="*44 + "\n")
    
    log(f"Management server started on http://localhost:{args.port}")
    print(f"\n  GUI:      http://localhost:{args.port}")
    print(f"  API:      http://localhost:{args.port}/api/*\n")
    print("Press Ctrl+C to stop\n")
    
    # Open browser
    if not args.no_browser:
        try:
            import webbrowser
            webbrowser.open(f'http://localhost:{args.port}')
        except:
            pass
    
    # Handle Ctrl+C gracefully
    def signal_handler(sig, frame):
        print("\n\nShutting down...")
        server.shutdown()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    # Start server in a thread so signal handler works
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()
    
    # Keep main thread alive
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n\nShutting down...")
        server.shutdown()


if __name__ == '__main__':
    main()
