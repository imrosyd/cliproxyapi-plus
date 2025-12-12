#!/bin/bash
# WSL Browser Wrapper - Opens URL in Windows default browser
# Usage: wsl-browser.sh <url>

URL="$1"

if [ -z "$URL" ]; then
    echo "Usage: $0 <url>"
    exit 1
fi

# Run cmd.exe from Windows directory to avoid UNC path error
cd /mnt/c 2>/dev/null || cd /tmp
/mnt/c/Windows/System32/cmd.exe /c start "" "$URL" 2>/dev/null
