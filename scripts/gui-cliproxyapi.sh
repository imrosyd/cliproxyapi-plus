#!/bin/bash
# CLIProxyAPIPlus GUI Control Center (Linux/macOS)
# Starts the Python management server and opens GUI in browser

set -e

# Default values
PORT=8318
NO_BROWSER=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port|-p)
            PORT="$2"; shift 2;;
        --no-browser|-n)
            NO_BROWSER=1; shift;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -p, --port PORT       Port for GUI server (default: 8318)"
            echo "  -n, --no-browser      Don't open browser automatically"
            echo "  -h, --help            Show this help message"
            exit 0;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1;;
    esac
done

# Find script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI_SERVER="$SCRIPT_DIR/gui-server.py"

# Check if Python 3 is available
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: Python 3 is required but not found"
    echo "Please install Python 3: sudo apt install python3"
    exit 1
fi

# Check if GUI server exists
if [ ! -f "$GUI_SERVER" ]; then
    echo "Error: GUI server not found at: $GUI_SERVER"
    exit 1
fi

# Make GUI server executable
chmod +x "$GUI_SERVER" 2>/dev/null || true

# Build arguments for Python server
PYTHON_ARGS=("--port" "$PORT")
if [ $NO_BROWSER -eq 1 ]; then
    PYTHON_ARGS+=("--no-browser")
fi

# Start the Python GUI server
exec python3 "$GUI_SERVER" "${PYTHON_ARGS[@]}"
