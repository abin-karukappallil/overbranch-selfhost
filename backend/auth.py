"""
backend/auth.py — Single-User Self-Host Authentication Resolver
Always authenticates the local user without requiring external auth tokens or DB session lookups.
"""

from typing import Dict, Any, Optional
from fastapi import Request

SELFHOST_USER: Dict[str, Any] = {
    "user_id": "selfhost-user",
    "id": "selfhost-user",
    "name": "Local Author",
    "email": "author@local",
    "role": "admin",
    "is_guest": False,
}

async def get_current_user(request: Request) -> Dict[str, Any]:
    return SELFHOST_USER

async def get_current_user_or_guest(request: Request) -> Dict[str, Any]:
    return SELFHOST_USER

def verify_project_ownership_or_member(client_or_db: Any, project_id: str, user_id: Optional[str] = None, is_guest: bool = False):
    """In single-user self-host mode, access is always granted."""
    return True

async def validate_better_auth_session(raw_token: str, db: Any = None) -> Optional[Dict[str, Any]]:
    return SELFHOST_USER

def extract_guest_token(request: Request) -> Optional[str]:
    return None
