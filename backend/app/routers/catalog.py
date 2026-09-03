"""Read-only catalogue endpoints."""

from __future__ import annotations

import math
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.models import Category, Product
from app.schemas import CategoryOut, ProductOut, ProductPage

router = APIRouter(tags=["catalog"])

Session = Annotated[AsyncSession, Depends(get_session)]

SORTS = {
    "featured": (Product.featured.desc(), Product.name.asc()),
    "price_asc": (Product.price_cents.asc(),),
    "price_desc": (Product.price_cents.desc(),),
    "name": (Product.name.asc(),),
}


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(session: Session) -> list[Category]:
    result = await session.scalars(select(Category).order_by(Category.sort_order))
    return list(result.all())


@router.get("/products", response_model=ProductPage)
async def list_products(
    session: Session,
    category: str | None = Query(default=None, description="Category slug"),
    surface: str | None = Query(default=None, description="chalk, dry-erase, glass, ..."),
    q: str | None = Query(default=None, max_length=120, description="Free-text search"),
    in_stock: bool = Query(default=False),
    sort: Literal["featured", "price_asc", "price_desc", "name"] = "featured",
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=12, ge=1, le=60),
) -> ProductPage:
    filters = []
    if category:
        filters.append(Product.category.has(Category.slug == category))
    if surface:
        filters.append(Product.surface == surface)
    if in_stock:
        filters.append(Product.stock > 0)
    if q:
        needle = f"%{q.strip().lower()}%"
        filters.append(
            or_(
                func.lower(Product.name).like(needle),
                func.lower(Product.summary).like(needle),
                func.lower(Product.description).like(needle),
            )
        )

    total = await session.scalar(select(func.count(Product.id)).where(*filters)) or 0
    stmt = (
        select(Product)
        .where(*filters)
        .order_by(*SORTS[sort])
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    items = (await session.scalars(stmt)).all()

    return ProductPage(
        items=[ProductOut.model_validate(p) for p in items],
        total=total,
        page=page,
        page_size=page_size,
        pages=max(1, math.ceil(total / page_size)),
    )


@router.get("/products/{slug}", response_model=ProductOut)
async def get_product(slug: str, session: Session) -> Product:
    product = await session.scalar(select(Product).where(Product.slug == slug))
    if product is None:
        raise HTTPException(status_code=404, detail="product not found")
    return product
