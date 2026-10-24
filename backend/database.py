"""
backend/database.py — Asynchronous SQLite Database Engine for OverBranch Self-Host
==================================================================================
Provides local SQLite storage replacing PostgreSQL and Supabase.
Stores projects, LaTeX documents, templates, preferences, and vector embeddings in a single file.
"""

from __future__ import annotations

import os
import sqlite3
import logging
from pathlib import Path
from typing import AsyncGenerator, Optional

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import declarative_base

logger = logging.getLogger("database")

Base = declarative_base()

def get_sqlite_path() -> Path:
    # Always resolve overbranch.db in overbranch-selfhost root folder
    parent_root = Path(__file__).resolve().parent.parent
    p = (parent_root / "overbranch.db").resolve()
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


_SQLITE_PATH = get_sqlite_path()
_ASYNC_DB_URL = f"sqlite+aiosqlite:///{_SQLITE_PATH}"

_async_engine: Optional[AsyncEngine] = None
_async_session_factory: Optional[async_sessionmaker[AsyncSession]] = None


def init_sqlite_schema():
    """Initializes SQLite schema tables synchronously if they do not exist."""
    db_path = get_sqlite_path()
    logger.info(f"Initializing local SQLite schema at: {db_path}")
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    
    cursor = conn.cursor()
    cursor.executescript("""
    CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL DEFAULT 'selfhost-user',
        name TEXT NOT NULL,
        description TEXT,
        repository TEXT,
        default_branch TEXT NOT NULL DEFAULT 'main.tex',
        language TEXT NOT NULL DEFAULT 'latex',
        status TEXT NOT NULL DEFAULT 'active',
        is_public INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        template TEXT NOT NULL DEFAULT 'IEEEtran',
        stars_count INTEGER NOT NULL DEFAULT 0,
        last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS project_members (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        user_id TEXT NOT NULL DEFAULT 'selfhost-user',
        role TEXT NOT NULL DEFAULT 'Owner',
        joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS latex_documents (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        raw_code TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        file_extension TEXT NOT NULL DEFAULT 'cls',
        is_featured INTEGER NOT NULL DEFAULT 0,
        usage_count INTEGER NOT NULL DEFAULT 0,
        content TEXT
    );

    CREATE TABLE IF NOT EXISTS user_preferences (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        theme TEXT NOT NULL DEFAULT 'dark',
        email_notifications INTEGER NOT NULL DEFAULT 0,
        security_alerts INTEGER NOT NULL DEFAULT 0,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS editor_preferences (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        font_size INTEGER NOT NULL DEFAULT 14,
        tab_size INTEGER NOT NULL DEFAULT 2,
        word_wrap INTEGER NOT NULL DEFAULT 1,
        auto_compile INTEGER NOT NULL DEFAULT 1,
        engine TEXT NOT NULL DEFAULT 'pdfLaTeX',
        line_numbers INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS document_vectors (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        chunk_id TEXT NOT NULL,
        title TEXT,
        content TEXT NOT NULL,
        embedding TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS comments (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        author_id TEXT NOT NULL DEFAULT 'selfhost-user',
        content TEXT NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Ensure default user and preferences exist
    INSERT OR IGNORE INTO user_preferences (id, user_id, theme, email_notifications, security_alerts)
    VALUES ('pref-default', 'selfhost-user', 'dark', 0, 0);

    INSERT OR IGNORE INTO editor_preferences (id, user_id, font_size, tab_size, word_wrap, auto_compile, engine, line_numbers)
    VALUES ('ed-pref-default', 'selfhost-user', 14, 2, 1, 1, 'pdfLaTeX', 1);
    """)
    conn.commit()
    conn.close()
    logger.info("SQLite schema initialization complete.")


def get_engine() -> AsyncEngine:
    global _async_engine
    if _async_engine is None:
        init_sqlite_schema()
        _async_engine = create_async_engine(
            _ASYNC_DB_URL,
            echo=False,
            future=True,
        )
    return _async_engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    global _async_session_factory
    if _async_session_factory is None:
        engine = get_engine()
        _async_session_factory = async_sessionmaker(
            bind=engine,
            class_=AsyncSession,
            expire_on_commit=False,
            autoflush=False,
        )
    return _async_session_factory


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def close_db():
    global _async_engine, _async_session_factory
    if _async_engine is not None:
        await _async_engine.dispose()
        _async_engine = None
        _async_session_factory = None
        logger.info("Local SQLite engine pool disposed.")
