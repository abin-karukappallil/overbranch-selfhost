"""
backend/vector_db.py — Local SQLite Vector Search & Embedding Engine for OverBranch Self-Host
==============================================================================================
Provides 100% local document chunking, dense vector embeddings, SQLite vector storage,
and cosine similarity search for LaTeX projects without external vector databases or API keys.
"""

from __future__ import annotations

import os
import re
import json
import math
import time
import uuid
import sqlite3
import hashlib
import logging
from pathlib import Path
from typing import List, Dict, Any, Optional

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from database import get_sqlite_path

logger = logging.getLogger("vector_db")
router = APIRouter()

# Embedding vector dimension
EMBEDDING_DIM = 384

_fastembed_model = None

def _get_fastembed_model():
    """Attempts to lazily load fastembed model if available in the environment."""
    global _fastembed_model
    if _fastembed_model is not None:
        return _fastembed_model
    try:
        from fastembed import TextEmbedding
        _fastembed_model = TextEmbedding(model_name="BAAI/bge-small-en-v1.5")
        logger.info("FastEmbed local ONNX model loaded successfully.")
        return _fastembed_model
    except Exception:
        return None


def generate_local_embedding(text: str) -> List[float]:
    """
    Generates a normalized 384-dimensional dense vector for input text.
    Uses fastembed if available, or falls back to a fast deterministic
    token & n-gram projection algorithm that runs anywhere with 0 external dependencies.
    """
    if not text or not text.strip():
        return [0.0] * EMBEDDING_DIM

    # 1. Try FastEmbed
    fe = _get_fastembed_model()
    if fe is not None:
        try:
            embeddings = list(fe.embed([text]))
            if embeddings and len(embeddings) > 0:
                vec = embeddings[0]
                return [float(x) for x in vec]
        except Exception as e:
            logger.debug(f"FastEmbed fallback to local hash-projection: {e}")

    # 2. High-performance deterministic semantic hash projection
    # Captures word unigrams, bigrams, and character trigrams (crucial for LaTeX macros like \section, \cite)
    vec = [0.0] * EMBEDDING_DIM
    words = re.findall(r"\b[A-Za-z0-9_\\]+\b", text.lower())
    
    # Unigrams & bigrams
    tokens = list(words)
    for i in range(len(words) - 1):
        tokens.append(f"{words[i]}_{words[i+1]}")
    
    # Substring character trigrams
    for i in range(min(len(text) - 2, 500)):
        tokens.append(text[i:i+3].lower())

    for token in tokens:
        # Murmur/md5 inspired 32-bit hash distribution across dimensions
        h = int(hashlib.md5(token.encode("utf-8")).hexdigest()[:8], 16)
        dim_idx = h % EMBEDDING_DIM
        sign = 1.0 if (h & 0x80000000) == 0 else -1.0
        vec[dim_idx] += sign * (1.0 / math.sqrt(len(token) + 1.0))

    # L2 normalize
    norm = math.sqrt(sum(v * v for v in vec))
    if norm > 1e-9:
        vec = [v / norm for v in vec]
    return vec


def cosine_similarity(v1: List[float], v2: List[float]) -> float:
    """Computes cosine similarity between two float vectors."""
    if len(v1) != len(v2):
        return 0.0
    dot = sum(a * b for a, b in zip(v1, v2))
    norm_a = math.sqrt(sum(a * a for a in v1))
    norm_b = math.sqrt(sum(b * b for b in v2))
    if norm_a <= 1e-9 or norm_b <= 1e-9:
        return 0.0
    return float(dot / (norm_a * norm_b))


def chunk_latex_code(code: str, file_path: str = "main.tex") -> List[Dict[str, Any]]:
    """
    Splits LaTeX document into semantic structural chunks:
    Preamble, Chapters, Sections, Subsections, Appendices, Environments, and Figures.
    """
    if not code or not code.strip():
        return []

    lines = code.splitlines()
    total_lines = len(lines)
    chunks: List[Dict[str, Any]] = []

    # Section regex pattern
    pattern = re.compile(
        r"^\\(?:chapter|section|subsection|subsubsection|paragraph|begin\{frame\})\*?(?:\[.*?\])?\{?(.*?)\}?$",
        re.MULTILINE
    )

    matches = list(pattern.finditer(code))
    if not matches:
        # Single document chunk
        return [{
            "chunk_id": "chunk-all",
            "title": file_path,
            "content": code[:4000],
            "start_line": 1,
            "end_line": total_lines,
        }]

    # 1. Preamble chunk (before first section)
    first_match = matches[0]
    first_line = code[:first_match.start()].count("\n") + 1
    if first_match.start() > 0:
        preamble_text = code[:first_match.start()].strip()
        if preamble_text:
            chunks.append({
                "chunk_id": "chunk-preamble",
                "title": "Preamble & Imports",
                "content": preamble_text[:2000],
                "start_line": 1,
                "end_line": first_line,
            })

    # 2. Section chunks
    for i, m in enumerate(matches):
        start_offset = m.start()
        end_offset = matches[i + 1].start() if i + 1 < len(matches) else len(code)
        chunk_content = code[start_offset:end_offset].strip()
        
        start_line = code[:start_offset].count("\n") + 1
        end_line = code[:end_offset].count("\n") + 1
        title = m.group(1).strip() if m.group(1) else m.group(0).strip()
        
        chunks.append({
            "chunk_id": f"chunk-{i+1}",
            "title": title[:100] or f"Section {i+1}",
            "content": chunk_content[:3000],
            "start_line": start_line,
            "end_line": end_line,
        })

    return chunks


def index_document_in_sqlite(project_id: str, file_path: str, code: str) -> List[Dict[str, Any]]:
    """Chunks the code, generates embeddings, and saves into SQLite document_vectors table."""
    chunks = chunk_latex_code(code, file_path)
    db_path = get_sqlite_path()
    
    conn = sqlite3.connect(str(db_path))
    try:
        # Remove existing vectors for this file in project
        conn.execute(
            "DELETE FROM document_vectors WHERE project_id = ? AND file_path = ?",
            (project_id, file_path),
        )
        
        for c in chunks:
            vec = generate_local_embedding(f"{c['title']} \n {c['content']}")
            vec_json = json.dumps(vec)
            conn.execute(
                """
                INSERT INTO document_vectors (id, project_id, file_path, chunk_id, title, content, embedding)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    f"{project_id}_{file_path}_{c['chunk_id']}",
                    project_id,
                    file_path,
                    c["chunk_id"],
                    c["title"],
                    c["content"],
                    vec_json,
                )
            )
        conn.commit()
    finally:
        conn.close()

    return chunks


def search_vector_db(project_id: str, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
    """Searches document vectors in SQLite using cosine similarity."""
    q_vec = generate_local_embedding(query)
    db_path = get_sqlite_path()
    
    conn = sqlite3.connect(str(db_path))
    rows = []
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT chunk_id, file_path, title, content, embedding FROM document_vectors WHERE project_id = ?",
            (project_id,),
        )
        rows = cursor.fetchall()
    finally:
        conn.close()

    scored = []
    for chunk_id, file_path, title, content, embedding_json in rows:
        try:
            emb = json.loads(embedding_json)
            sim = cosine_similarity(q_vec, emb)
            scored.append({
                "chunk_id": chunk_id,
                "file_path": file_path,
                "title": title,
                "content": content,
                "score": round(sim, 4),
            })
        except Exception:
            continue

    scored.sort(key=lambda x: x["score"], reverse=True)
    return scored[:top_k]


# ============================================================================
# API Endpoints
# ============================================================================

class SyncFileRequest(BaseModel):
    project_id: str
    file_path: str = "main.tex"
    new_code: str


class VectorSearchRequest(BaseModel):
    project_id: str
    query: str
    top_k: int = 5


@router.post("/api/sync-file")
async def sync_file_endpoint(req: SyncFileRequest):
    """
    Syncs a file to local disk, updates SQLite latex_documents,
    and indexes chunks in the SQLite vector database.
    """
    project_id = req.project_id
    file_path = req.file_path or "main.tex"
    code = req.new_code or ""

    # 1. Save to local project directory on disk
    from project_storage import UPLOADS_BASE_DIR, get_project_disk_path
    try:
        target_path = get_project_disk_path(project_id, file_path)
        target_path.parent.mkdir(parents=True, exist_ok=True)
        with open(target_path, "w", encoding="utf-8") as f:
            f.write(code)
    except Exception as e:
        logger.warning(f"Error writing to disk in sync-file: {e}")

    # 2. Upsert to SQLite latex_documents
    db_path = get_sqlite_path()
    conn = sqlite3.connect(str(db_path))
    try:
        conn.execute(
            """
            INSERT INTO latex_documents (id, project_id, file_path, raw_code, updated_at)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(id) DO UPDATE SET raw_code = excluded.raw_code, updated_at = CURRENT_TIMESTAMP
            """,
            (f"{project_id}_{file_path}", project_id, file_path, code),
        )
        conn.commit()
    except Exception as e:
        logger.warning(f"Error saving to latex_documents in sync-file: {e}")
    finally:
        conn.close()

    # 3. Index in SQLite Vector Store
    chunks = []
    try:
        chunks = index_document_in_sqlite(project_id, file_path, code)
    except Exception as e:
        logger.warning(f"Error indexing chunks in vector db: {e}")

    return {
        "synced": True,
        "project_id": project_id,
        "file_path": file_path,
        "chunks": chunks,
    }


@router.post("/api/vector-search")
async def vector_search_endpoint(req: VectorSearchRequest):
    """Semantic vector search against project LaTeX chunks."""
    results = search_vector_db(req.project_id, req.query, req.top_k)
    return {
        "project_id": req.project_id,
        "query": req.query,
        "results": results,
    }
