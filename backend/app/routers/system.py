"""Health probes and the deployment-introspection endpoint.

`/api/health` is the ALB / ECS liveness probe; `/api/health/ready` also touches
the database, so a task with a broken RDS route is pulled out of the target
group instead of serving 500s. `/api/meta` is what the "How this is deployed"
page in the SPA renders.
"""

from __future__ import annotations

import os
import socket
import time
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Response
from sqlalchemy import make_url, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db import get_session
from app.schemas import DatabaseMeta, MetaOut

router = APIRouter(tags=["system"])

Session = Annotated[AsyncSession, Depends(get_session)]

STARTED_AT = time.monotonic()
HOSTNAME = socket.gethostname()


def _task_id() -> str | None:
    """Best-effort Fargate task identity.

    In awsvpc mode the container hostname is the task id, but ECS also exposes a
    metadata URI whose last path segment is the task's docker id - either is
    enough to tell two tasks apart in the UI.
    """
    uri = os.getenv("ECS_CONTAINER_METADATA_URI_V4") or os.getenv("ECS_CONTAINER_METADATA_URI")
    if uri:
        return uri.rstrip("/").rsplit("/", 1)[-1]
    return os.getenv("HOSTNAME") or None


async def _database_meta(session: AsyncSession) -> DatabaseMeta:
    url = make_url(get_settings().database_url)
    started = time.perf_counter()
    try:
        await session.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001 - reported, never raised, to the UI
        return DatabaseMeta(
            dialect=url.get_backend_name(),
            host=url.host or "local",
            name=url.database or "",
            reachable=False,
            error=type(exc).__name__,
        )
    return DatabaseMeta(
        dialect=url.get_backend_name(),
        host=url.host or "local",
        name=url.database or "",
        reachable=True,
        latency_ms=round((time.perf_counter() - started) * 1000, 2),
    )


@router.get("/health", include_in_schema=False)
async def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/health/ready", include_in_schema=False)
async def ready(session: Session, response: Response) -> dict[str, object]:
    db = await _database_meta(session)
    if not db.reachable:
        response.status_code = 503
    return {"status": "ok" if db.reachable else "degraded", "database": db.model_dump()}


@router.get("/meta", response_model=MetaOut)
async def meta(session: Session) -> MetaOut:
    settings = get_settings()
    return MetaOut(
        service="nib-shop-api",
        version=settings.app_version,
        git_sha=settings.git_sha,
        environment=settings.environment,
        region=settings.aws_region or "local",
        served_by=HOSTNAME,
        task_id=_task_id(),
        uptime_seconds=round(time.monotonic() - STARTED_AT, 1),
        served_at=datetime.now(UTC),
        database=await _database_meta(session),
    )
