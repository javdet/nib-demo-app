"""Server-side carts.

The browser holds nothing but a cart id in localStorage; quantities, prices and
availability all come from Postgres, which is what makes this demo actually
exercise the database on every interaction.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.models import Cart, CartItem, Product
from app.schemas import CartItemIn, CartItemQuantityIn, CartOut
from app.services import get_or_create_cart, load_cart_item, serialize_cart

router = APIRouter(prefix="/carts", tags=["cart"])

Session = Annotated[AsyncSession, Depends(get_session)]


async def _reload(session: AsyncSession, cart_id: str) -> Cart:
    """Re-read the cart so the eager loaders see the mutation we just made."""
    cart = await session.get(Cart, cart_id, populate_existing=True)
    if cart is None:  # pragma: no cover - only reachable on a concurrent delete
        raise HTTPException(status_code=404, detail="cart not found")
    return cart


async def _require_cart(session: AsyncSession, cart_id: str) -> Cart:
    cart = await session.get(Cart, cart_id)
    if cart is None:
        raise HTTPException(status_code=404, detail="cart not found")
    return cart


@router.post("", response_model=CartOut, status_code=201)
async def create_cart(session: Session) -> CartOut:
    cart = await get_or_create_cart(session, None)
    await session.commit()
    return serialize_cart(await _reload(session, cart.id))


@router.get("/{cart_id}", response_model=CartOut)
async def get_cart(cart_id: str, session: Session) -> CartOut:
    return serialize_cart(await _require_cart(session, cart_id))


@router.post("/{cart_id}/items", response_model=CartOut)
async def add_item(cart_id: str, payload: CartItemIn, session: Session) -> CartOut:
    cart = await _require_cart(session, cart_id)
    product = await session.get(Product, payload.product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="product not found")

    existing = next((i for i in cart.items if i.product_id == product.id), None)
    wanted = (existing.quantity if existing else 0) + payload.quantity
    if wanted > product.stock:
        raise HTTPException(
            status_code=409, detail=f"only {product.stock} x {product.name} left in stock"
        )

    if existing is not None:
        existing.quantity = wanted
    else:
        session.add(CartItem(cart_id=cart.id, product_id=product.id, quantity=payload.quantity))

    await session.commit()
    return serialize_cart(await _reload(session, cart.id))


@router.patch("/{cart_id}/items/{item_id}", response_model=CartOut)
async def set_quantity(
    cart_id: str, item_id: int, payload: CartItemQuantityIn, session: Session
) -> CartOut:
    await _require_cart(session, cart_id)
    item = await load_cart_item(session, cart_id, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="cart item not found")

    if payload.quantity == 0:
        await session.delete(item)
    else:
        if payload.quantity > item.product.stock:
            raise HTTPException(
                status_code=409,
                detail=f"only {item.product.stock} x {item.product.name} left in stock",
            )
        item.quantity = payload.quantity

    await session.commit()
    return serialize_cart(await _reload(session, cart_id))


@router.delete("/{cart_id}/items/{item_id}", response_model=CartOut)
async def remove_item(cart_id: str, item_id: int, session: Session) -> CartOut:
    await _require_cart(session, cart_id)
    item = await load_cart_item(session, cart_id, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="cart item not found")
    await session.delete(item)
    await session.commit()
    return serialize_cart(await _reload(session, cart_id))
