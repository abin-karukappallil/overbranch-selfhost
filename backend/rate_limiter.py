"""
backend/rate_limiter.py — Permissive Local Rate Limiter for OverBranch Self-Host
"""

from fastapi import Request

class RateLimiter:
    """Pass-through rate limiter for local single-user self-hosting."""
    def __init__(self, times: int = 60, seconds: int = 60, key_prefix: str = "rl"):
        self.times = times
        self.seconds = seconds
        self.key_prefix = key_prefix

    async def __call__(self, request: Request) -> None:
        return
