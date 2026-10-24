"""
web2api_keys.py — Hardcoded Gemini Web2API credentials for OverBranch Self-Host.
Zero .env setup needed: connects directly to local Go proxy at http://localhost:8081/v1.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List


@dataclass(frozen=True)
class Web2ApiKey:
    name: str
    key: str


def get_web2api_base_url(namespace: str = "GEMINI") -> str:
    return "http://localhost:8081/v1"


def load_web2api_keys(namespace: str = "GEMINI") -> List[Web2ApiKey]:
    return [Web2ApiKey(name="Local Web2API", key="local")]
