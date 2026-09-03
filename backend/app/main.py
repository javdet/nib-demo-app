"""FastAPI application factory."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db import SessionLocal
from app.routers import cart, catalog, orders, system
from app.seed import seed_catalog

log = logging.getLogger("nib.shop")

DESCRIPTION = """
Backend for **Nib & Slate**, a demo storefront selling chalkboards and other
drawing surfaces. It exists to show a React SPA on S3/CloudFront talking to a
containerised Python API talking to Postgres.
"""


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    if settings.seed_on_startup:
        try:
            async with SessionLocal() as session:
                created, updated = await seed_catalog(session)
            log.info("catalogue ready (%d created, %d updated)", created, updated)
        except Exception:  # noqa: BLE001 - a seeding failure must not stop the task
            log.exception("catalogue seeding failed; serving whatever is already in the database")
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Nib & Slate API",
        description=DESCRIPTION,
        version=settings.app_version,
        root_path=settings.root_path,
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    for router in (system.router, catalog.router, cart.router, orders.router):
        app.include_router(router, prefix="/api")
    return app


app = create_app()
