#!/usr/bin/env python3
"""Compatibility shim: all logic lives in install.sh / install.ps1."""
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
if os.name == "nt":
    cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", os.path.join(here, "install.ps1")]
else:
    cmd = ["bash", os.path.join(here, "install.sh")]
sys.exit(subprocess.call(cmd + sys.argv[1:]))
