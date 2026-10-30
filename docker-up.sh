#!/usr/bin/env bash
# Compatibility shim: all logic lives in install.sh.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh" "$@"
