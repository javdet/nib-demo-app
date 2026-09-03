"""Idempotent catalogue seeding.

Runs on startup (unless SEED_ON_STARTUP=false) and is also importable as a
one-shot script: `python -m app.seed`. Existing products are updated in place
rather than duplicated, so re-running it after a catalogue edit is safe.
"""

from __future__ import annotations

import asyncio
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.data.catalog import CATEGORIES, PRODUCTS
from app.db import SessionLocal
from app.models import Category, Product

log = logging.getLogger(__name__)


async def seed_catalog(session: AsyncSession) -> tuple[int, int]:
    """Insert or refresh every category and product. Returns (created, updated)."""
    created = updated = 0

    existing_categories = {c.slug: c for c in (await session.scalars(select(Category))).all()}
    for payload in CATEGORIES:
        category = existing_categories.get(payload["slug"])
        if category is None:
            category = Category(**payload)
            session.add(category)
            existing_categories[payload["slug"]] = category
            created += 1
        else:
            for field, value in payload.items():
                setattr(category, field, value)
            updated += 1
    await session.flush()

    existing_products = {p.slug: p for p in (await session.scalars(select(Product))).all()}
    for payload in PRODUCTS:
        data = dict(payload)
        category = existing_categories[data.pop("category")]
        product = existing_products.get(data["slug"])
        if product is None:
            session.add(Product(category_id=category.id, **data))
            created += 1
        else:
            product.category_id = category.id
            for field, value in data.items():
                setattr(product, field, value)
            updated += 1

    await session.commit()
    return created, updated


async def main() -> None:
    logging.basicConfig(level=logging.INFO)
    async with SessionLocal() as session:
        created, updated = await seed_catalog(session)
    log.info("catalogue seeded: %d created, %d updated", created, updated)


if __name__ == "__main__":
    asyncio.run(main())
