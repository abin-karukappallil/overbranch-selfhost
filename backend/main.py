import os
import asyncio
import logging
from pathlib import Path
import logging
from contextlib import asynccontextmanager
from typing import List, Optional, Dict, Any

from fastapi import FastAPI, Request, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from compiler import compile_latex
from compile_queue import compile_queue, CompileQueueFullError
import project_storage
import file_analyzer
import template_service

logger = logging.getLogger("main")

_cleanup_task: Optional[asyncio.Task] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting OverBranch Self-Host TeX Engine API...")
    # Augment system PATH with MiKTeX / TeX Live binaries
    try:
        from compiler import augment_path_for_latex
        augment_path_for_latex()
    except Exception as e:
        logger.warning(f"Could not augment system PATH for LaTeX: {e}")

    # Initialize SQLite database schema
    try:
        from database import init_sqlite_schema
        init_sqlite_schema()
    except Exception as e:
        logger.error(f"Failed to initialize SQLite schema: {e}")

    yield

    logger.info("OverBranch TeX Engine API shutting down gracefully...")
    from database import close_db
    try:
        await close_db()
    except Exception as e:
        logger.warning(f"Error closing database pool: {e}")

    try:
        from compile_queue import compile_queue
        if getattr(compile_queue, "_executor", None) is not None:
            compile_queue._executor.shutdown(wait=False, cancel_futures=True)
    except Exception as e:
        logger.warning(f"Error shutting down compile executor: {e}")

    logger.info("OverBranch Self-Host shutdown complete.")


app = FastAPI(title="OverBranch TeX Engine API", version="1.0.0", lifespan=lifespan)

origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Trust reverse proxy headers (Cloudflare -> Nginx -> Docker) so request.client.host
# and logs resolve the real visitor IP instead of 127.0.0.1
app.add_middleware(ProxyHeadersMiddleware, trusted_hosts=["*"])

from routes.pdf_convert import router as pdf_convert_router
from routes.agent_routes import router as agent_router
from vector_db import router as vector_router

app.include_router(project_storage.router)
app.include_router(vector_router)
app.include_router(template_service.router)
app.include_router(file_analyzer.router, prefix="/api")
app.include_router(pdf_convert_router)
app.include_router(agent_router)

from routes import project_import
from routes import project_export
app.include_router(project_import.router, prefix='/api/projects')
app.include_router(project_export.router, prefix='/api/projects')


class FileAsset(BaseModel):
    filename: str
    data: str


class CompileRequest(BaseModel):
    latex_code: str = ""
    latex: str = ""
    project_id: str = ""
    engine: str = "latexmk"
    images: Optional[List[FileAsset]] = []
    files: Optional[List[FileAsset]] = []
    active_file: Optional[str] = None
    active_text: Optional[str] = None


@app.get("/api/models")
def list_models():
    """
    The models the editor may offer and which one is selected by default.

    The frontend has always fetched this path (``trpc/routers/ai.ts``); until it
    existed the call 404'd and the browser fell back to its own hardcoded list,
    so the default model was really defined in TypeScript. The backend's
    ``provider_router`` is the single source of truth, and this is how it reaches
    the client.
    """
    from providers.router import provider_router

    return provider_router.get_available_models()


@app.get("/api/health")
def health_check():
    return {
        "status": "ok",
        "service": "OverBranch Python Engine",
        "version": "1.0.0",
        "active_compiles": compile_queue.active_count,
        "waiting_compiles": compile_queue.waiting_count,
    }


from fastapi import Depends
from auth import get_current_user_or_guest, verify_project_ownership_or_member
from rate_limiter import RateLimiter
from project_storage import get_supabase_client


# How long a compile waits for the project's collab room to persist. The flush
# is normally milliseconds (a few disk writes); the cap only stops a wedged room
# from hanging the request.
COLLAB_FLUSH_TIMEOUT_SECONDS = 2.0


async def _flush_collab_room_before_compile(project_id: str) -> None:
    """In self-host mode without realtime collab, files are directly saved to disk and SQLite."""
    pass


@app.post(
    "/api/compile",
    dependencies=[Depends(RateLimiter(times=60, seconds=60, key_prefix="rl_compile"))],
)
async def compile_endpoint(
    req: CompileRequest,
    request: Request,
    auth_info: Dict[str, Any] = Depends(get_current_user_or_guest),
):
    """
    Protected TeX compilation endpoint.
    Requires an active Better Auth session or verified guest identity.
    """
    user_id = auth_info.get("user_id")
    is_guest = bool(auth_info.get("is_guest"))
    if user_id and req.project_id:
        try:
            sb = get_supabase_client()
            verify_project_ownership_or_member(sb, req.project_id, user_id, is_guest=is_guest)
        except Exception as e:
            logger.warning(f"Project compile verification warning: {e}")
            raise

    code = req.latex_code if req.latex_code.strip() else req.latex
    images_dict = [{"filename": img.filename, "data": img.data} for img in (req.images or [])]
    files_dict = [{"filename": f.filename, "data": f.data} for f in (req.files or [])]

    await _flush_collab_room_before_compile(req.project_id)

    try:
        result = await compile_queue.submit(
            compile_latex,
            latex_code=code,
            engine=req.engine,
            images=images_dict,
            files=files_dict,
            project_id=req.project_id,
            active_file=req.active_file,
            active_text=req.active_text,
        )
        return result
    except CompileQueueFullError as qfe:
        return JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={
                "detail": str(qfe),
                "retry_after_seconds": qfe.estimated_wait_s,
            },
            headers={"Retry-After": str(int(qfe.estimated_wait_s))},
        )


class SyncTeXBackwardRequest(BaseModel):
    page: int
    x: float
    y: float
    project_id: Optional[str] = None


class SyncTeXForwardRequest(BaseModel):
    file: str
    line: int
    column: Optional[int] = 1
    project_id: Optional[str] = None


@app.post(
    "/api/synctex/backward",
    dependencies=[Depends(RateLimiter(times=120, seconds=60, key_prefix="rl_synctex"))],
)
async def synctex_backward_endpoint(
    req: SyncTeXBackwardRequest,
    request: Request,
    auth_info: Dict[str, Any] = Depends(get_current_user_or_guest),
):
    from synctex_service import backward_lookup
    user_id = auth_info.get("user_id")
    is_guest = bool(auth_info.get("is_guest"))
    if user_id and req.project_id:
        try:
            sb = get_supabase_client()
            verify_project_ownership_or_member(sb, req.project_id, user_id, is_guest=is_guest)
        except Exception as e:
            logger.warning(f"SyncTeX backward auth check warning: {e}")
            raise

    res = backward_lookup(
        project_id=req.project_id,
            active_file=req.active_file,
            active_text=req.active_text,
        page=req.page,
        x=req.x,
        y=req.y,
    )
    if not res:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No SyncTeX mapping found for this position"
        )
    return res


@app.post(
    "/api/synctex/forward",
    dependencies=[Depends(RateLimiter(times=120, seconds=60, key_prefix="rl_synctex"))],
)
async def synctex_forward_endpoint(
    req: SyncTeXForwardRequest,
    request: Request,
    auth_info: Dict[str, Any] = Depends(get_current_user_or_guest),
):
    from synctex_service import forward_lookup
    user_id = auth_info.get("user_id")
    is_guest = bool(auth_info.get("is_guest"))
    if user_id and req.project_id:
        try:
            sb = get_supabase_client()
            verify_project_ownership_or_member(sb, req.project_id, user_id, is_guest=is_guest)
        except Exception as e:
            logger.warning(f"SyncTeX forward auth check warning: {e}")
            raise

    res = forward_lookup(
        project_id=req.project_id,
            active_file=req.active_file,
            active_text=req.active_text,
        file_path=req.file,
        line=req.line,
        column=req.column or 1,
    )
    if not res:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No SyncTeX mapping found for this source line"
        )
    return res


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, proxy_headers=True, forwarded_allow_ips="*")

