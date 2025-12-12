# Bug Report: Browser Opens on Server Instead of Client (WSL/Tunnel)

## Issue
When accessing GUI through Cloudflare tunnel or remote connection, OAuth login opens the browser on the **server** instead of the **client browser**.

## Environment
- WSL (Windows Subsystem for Linux)
- Cloudflare tunnel for remote access
- CLIProxyAPI-Plus GUI served on port 8318

## Current Behavior
1. User accesses GUI via `https://tunnel-url/`
2. User clicks on a provider login button (e.g., Copilot)
3. **Browser opens on the WSL server** (Chrome on Windows via WSL)
4. User on tunnel cannot see this browser window

## Expected Behavior
1. User accesses GUI via tunnel
2. User clicks login button
3. **Browser opens on user's device** (client-side)
4. User can authenticate

## Root Cause Analysis
The CLI binary (`cliproxyapi-plus`) opens browser internally using Go's `browser.OpenURL()` function. This bypasses the `BROWSER` environment variable in some cases.

Attempts to fix:
- Set `BROWSER=/bin/true` → Binary may use fallback methods
- Unset `DISPLAY` → Binary may use Windows browser directly in WSL
- The binary has hardcoded browser opening logic

## Workaround Implemented
- GUI now returns `login_url` and `device_code` to client
- Frontend uses `window.open()` to open URL client-side
- However, binary **ALSO** opens browser server-side

## Proposed Solutions

### Option 1: CLI Flag (Recommended)
Add `--no-browser` flag to CLI binary that prevents automatic browser opening:
```
cliproxyapi-plus --login --no-browser
```
This would output URL to stdout without opening browser.

### Option 2: Environment Variable
CLI respects a specific env var like `CLIPROXYAPI_NO_BROWSER=1` to disable browser.

### Option 3: Modify GUI Server
Accept the dual browser opening - user ignores server browser, uses client-side popup.

## Current Status
- ✅ `login_url` returned to GUI client
- ✅ `device_code` extracted and returned
- ✅ `window.open()` opens URL in client browser
- ❌ CLI binary still opens browser on server (WSL)

## Files Modified
- `scripts/gui-server.py` - Returns `login_url` and `device_code`
- `gui/index.html` - Uses `window.open()` client-side

## Priority
Medium - Affects remote/tunnel users

## Date
2025-12-12
