"""Pydantic models for the public API surface."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    slug: str
    name: str
    tagline: str


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    name: str
    surface: str
    price_cents: int
    width_mm: int | None
    height_mm: int | None
    summary: str
    description: str
    stock: int
    featured: bool
    accent: str
    category: CategoryOut

    @property
    def in_stock(self) -> bool:
        return self.stock > 0


class ProductPage(BaseModel):
    items: list[ProductOut]
    total: int
    page: int
    page_size: int
    pages: int


class CartItemIn(BaseModel):
    product_id: int
    quantity: int = Field(default=1, ge=1, le=99)


class CartItemQuantityIn(BaseModel):
    quantity: int = Field(ge=0, le=99)


class CartItemOut(BaseModel):
    id: int
    quantity: int
    line_total_cents: int
    product: ProductOut


class CartOut(BaseModel):
    id: str
    items: list[CartItemOut]
    item_count: int
    subtotal_cents: int
    shipping_cents: int
    total_cents: int
    free_shipping_threshold_cents: int


class CheckoutIn(BaseModel):
    cart_id: str
    customer_name: str = Field(min_length=2, max_length=160)
    email: EmailStr
    address: str = Field(min_length=3, max_length=255)
    city: str = Field(min_length=1, max_length=120)
    postal_code: str = Field(min_length=1, max_length=32)
    country: str = Field(min_length=2, max_length=120)
    note: str = Field(default="", max_length=500)

    @field_validator("customer_name", "address", "city", "postal_code", "country", "note")
    @classmethod
    def _strip(cls, value: str) -> str:
        return value.strip()


class OrderItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    product_slug: str
    product_name: str
    unit_price_cents: int
    quantity: int


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    number: str
    status: str
    customer_name: str
    email: str
    address: str
    city: str
    postal_code: str
    country: str
    note: str
    subtotal_cents: int
    shipping_cents: int
    total_cents: int
    created_at: datetime
    items: list[OrderItemOut]


class DatabaseMeta(BaseModel):
    dialect: str
    host: str
    name: str
    reachable: bool
    latency_ms: float | None = None
    error: str | None = None


class MetaOut(BaseModel):
    """Everything the 'How this is deployed' page needs to prove itself.

    The interesting field is `served_by`: with several Fargate tasks behind the
    ALB, refreshing the page shows the request landing on different containers.
    """

    service: str
    version: str
    git_sha: str
    environment: str
    region: str
    served_by: str
    task_id: str | None
    uptime_seconds: float
    served_at: datetime
    database: DatabaseMeta
