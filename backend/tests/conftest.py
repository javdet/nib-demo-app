"""Test fixtures.

The suite runs against an in-memory SQLite database so it needs no Postgres and
no Docker; the models are deliberately dialect-neutral to make that possible.
"""

from __future__ import annotations

import os
from collections.abc import AsyncIterator

os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("SEED_ON_STARTUP", "false")

import pytest  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy.ext.asyncio import (  # noqa: E402
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import StaticPool  # noqa: E402

from app import db as db_module  # noqa: E402
from app.db import Base, get_session  # noqa: E402
from app.main import create_app  # noqa: E402
from app.seed import seed_catalog  # noqa: E402


@pytest.fixture
async def engine() -> AsyncIterator:
    # StaticPool keeps every session on the same in-memory database.
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
async def sessionmaker_(engine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


@pytest.fixture
async def seeded(sessionmaker_) -> None:
    async with sessionmaker_() as session:
        await seed_catalog(session)


@pytest.fixture
async def client(sessionmaker_, seeded, monkeypatch) -> AsyncIterator[AsyncClient]:
    # /api/meta reads the module-level engine, so point that at the test one too.
    monkeypatch.setattr(db_module, "SessionLocal", sessionmaker_)

    app = create_app()

    async def override_session() -> AsyncIterator[AsyncSession]:
        async with sessionmaker_() as session:
            yield session

    app.dependency_overrides[get_session] = override_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
async def cart_id(client: AsyncClient) -> str:
    response = await client.post("/api/carts")
    assert response.status_code == 201
    return response.json()["id"]


@pytest.fixture
async def product(client: AsyncClient) -> dict:
    response = await client.get("/api/products/slate-classic-900")
    assert response.status_code == 200
    return response.json()
