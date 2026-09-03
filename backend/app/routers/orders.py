"""Checkout. No payment provider - the order is confirmed on the spot."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.models import Cart, Order
from app.schemas import CheckoutIn, OrderOut
from app.services import CheckoutError, place_order

router = APIRouter(prefix="/orders", tags=["orders"])

Session = Annotated[AsyncSession, Depends(get_session)]


@router.post("", response_model=OrderOut, status_code=201)
async def checkout(payload: CheckoutIn, session: Session) -> Order:
    cart = await session.get(Cart, payload.cart_id)
    if cart is None:
        raise HTTPException(status_code=404, detail="cart not found")

    details = payload.model_dump(exclude={"cart_id"})
    details["email"] = str(details["email"])
    try:
        return await place_order(session, cart, details)
    except CheckoutError as exc:
        await session.rollback()
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.get("/{number}", response_model=OrderOut)
async def get_order(number: str, session: Session) -> Order:
    order = await session.scalar(select(Order).where(Order.number == number.upper()))
    if order is None:
        raise HTTPException(status_code=404, detail="order not found")
    return order
