#!/usr/bin/env bash
# Compatibility shim: all logic lives in install.sh (also works via curl | bash).
d="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd)"
if [ -f "$d/install.sh" ]; then exec bash "$d/install.sh" "$@"; fi
curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.sh | bash -s -- "$@"
