"""Pricing and checkout rules shared by the cart and order endpoints."""

from __future__ import annotations

import random
import string

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models import Cart, CartItem, Order, OrderItem
from app.schemas import CartItemOut, CartOut, ProductOut

ORDER_NUMBER_ALPHABET = string.ascii_uppercase + string.digits


class CheckoutError(Exception):
    """Raised when a cart cannot become an order (empty, or stock ran out)."""

    def __init__(self, message: str, *, status_code: int = 409) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def shipping_for(subtotal_cents: int) -> int:
    settings = get_settings()
    if subtotal_cents == 0:
        return 0
    if subtotal_cents >= settings.free_shipping_threshold_cents:
        return 0
    return settings.shipping_flat_cents


def serialize_cart(cart: Cart) -> CartOut:
    settings = get_settings()
    items: list[CartItemOut] = []
    subtotal = 0
    for item in sorted(cart.items, key=lambda i: i.id):
        line_total = item.product.price_cents * item.quantity
        subtotal += line_total
        items.append(
            CartItemOut(
                id=item.id,
                quantity=item.quantity,
                line_total_cents=line_total,
                product=ProductOut.model_validate(item.product),
            )
        )
    shipping = shipping_for(subtotal)
    return CartOut(
        id=cart.id,
        items=items,
        item_count=sum(i.quantity for i in items),
        subtotal_cents=subtotal,
        shipping_cents=shipping,
        total_cents=subtotal + shipping,
        free_shipping_threshold_cents=settings.free_shipping_threshold_cents,
    )


async def generate_order_number(session: AsyncSession) -> str:
    """A short, human-readable order number: NIB-XXXXXX."""
    for _ in range(10):
        candidate = "NIB-" + "".join(random.choices(ORDER_NUMBER_ALPHABET, k=6))
        clash = await session.scalar(select(Order.id).where(Order.number == candidate))
        if clash is None:
            return candidate
    raise CheckoutError("could not allocate an order number", status_code=503)


async def place_order(session: AsyncSession, cart: Cart, details: dict) -> Order:
    """Turn a cart into an order, decrementing stock and emptying the cart."""
    if not cart.items:
        raise CheckoutError("cart is empty", status_code=400)

    subtotal = 0
    order_items: list[OrderItem] = []
    for item in sorted(cart.items, key=lambda i: i.id):
        product = item.product
        if product.stock < item.quantity:
            raise CheckoutError(
                f"only {product.stock} x {product.name} left in stock",
                status_code=409,
            )
        product.stock -= item.quantity
        subtotal += product.price_cents * item.quantity
        order_items.append(
            OrderItem(
                product_id=product.id,
                product_slug=product.slug,
                product_name=product.name,
                unit_price_cents=product.price_cents,
                quantity=item.quantity,
            )
        )

    shipping = shipping_for(subtotal)
    order = Order(
        number=await generate_order_number(session),
        subtotal_cents=subtotal,
        shipping_cents=shipping,
        total_cents=subtotal + shipping,
        status="confirmed",
        items=order_items,
        **details,
    )
    session.add(order)

    # The cart has done its job; drop it so a stale id cannot be checked out twice.
    for item in list(cart.items):
        await session.delete(item)
    await session.delete(cart)

    await session.commit()
    await session.refresh(order)
    return order


async def get_or_create_cart(session: AsyncSession, cart_id: str | None) -> Cart:
    if cart_id:
        cart = await session.get(Cart, cart_id)
        if cart is not None:
            return cart
    cart = Cart()
    session.add(cart)
    await session.flush()
    return cart


async def load_cart_item(session: AsyncSession, cart_id: str, item_id: int) -> CartItem | None:
    return await session.scalar(
        select(CartItem).where(CartItem.id == item_id, CartItem.cart_id == cart_id)
    )
