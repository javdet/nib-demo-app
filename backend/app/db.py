"""Engine, session factory and the declarative base."""

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings


class Base(DeclarativeBase):
    pass


def build_engine():
    settings = get_settings()
    kwargs: dict = {"echo": settings.db_echo, "future": True}
    if not settings.is_sqlite:
        # Fargate tasks are small and RDS connection slots are finite: keep the
        # per-task pool modest and recycle before RDS drops idle connections.
        kwargs.update(
            pool_size=settings.db_pool_size,
            max_overflow=settings.db_max_overflow,
            pool_pre_ping=True,
            pool_recycle=1800,
        )
    return create_async_engine(settings.database_url, **kwargs)


engine = build_engine()
SessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


async def get_session() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        yield session
