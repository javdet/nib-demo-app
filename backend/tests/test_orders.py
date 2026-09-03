from httpx import AsyncClient

CUSTOMER = {
    "customer_name": "Ada Lovelace",
    "email": "ada@example.com",
    "address": "12 Analytical Way",
    "city": "London",
    "postal_code": "NW1 4RY",
    "country": "United Kingdom",
    "note": "Leave with the porter",
}


async def _cart_with(client: AsyncClient, cart_id: str, slug: str, quantity: int = 1) -> dict:
    product = (await client.get(f"/api/products/{slug}")).json()
    await client.post(
        f"/api/carts/{cart_id}/items", json={"product_id": product["id"], "quantity": quantity}
    )
    return product


async def test_checkout_creates_an_order_and_clears_the_cart(client: AsyncClient, cart_id) -> None:
    product = await _cart_with(client, cart_id, "slate-classic-900", 2)

    response = await client.post("/api/orders", json={"cart_id": cart_id, **CUSTOMER})
    assert response.status_code == 201
    order = response.json()

    assert order["number"].startswith("NIB-")
    assert order["status"] == "confirmed"
    assert order["subtotal_cents"] == product["price_cents"] * 2
    assert order["total_cents"] == order["subtotal_cents"] + order["shipping_cents"]
    assert order["items"][0]["product_slug"] == "slate-classic-900"
    assert order["items"][0]["quantity"] == 2

    # The cart is consumed, so the same id cannot be checked out twice.
    assert (await client.get(f"/api/carts/{cart_id}")).status_code == 404


async def test_checkout_decrements_stock(client: AsyncClient, cart_id) -> None:
    before = (await client.get("/api/products/studio-slate-xl")).json()["stock"]
    await _cart_with(client, cart_id, "studio-slate-xl", 2)
    await client.post("/api/orders", json={"cart_id": cart_id, **CUSTOMER})

    after = (await client.get("/api/products/studio-slate-xl")).json()["stock"]
    assert after == before - 2


async def test_order_is_retrievable_by_number(client: AsyncClient, cart_id) -> None:
    await _cart_with(client, cart_id, "dustless-chalk-set")
    number = (await client.post("/api/orders", json={"cart_id": cart_id, **CUSTOMER})).json()[
        "number"
    ]

    fetched = (await client.get(f"/api/orders/{number.lower()}")).json()
    assert fetched["number"] == number
    assert fetched["customer_name"] == "Ada Lovelace"


async def test_empty_cart_cannot_be_checked_out(client: AsyncClient, cart_id) -> None:
    response = await client.post("/api/orders", json={"cart_id": cart_id, **CUSTOMER})
    assert response.status_code == 400


async def test_invalid_email_is_rejected(client: AsyncClient, cart_id) -> None:
    await _cart_with(client, cart_id, "dustless-chalk-set")
    payload = {"cart_id": cart_id, **CUSTOMER, "email": "not-an-email"}
    assert (await client.post("/api/orders", json=payload)).status_code == 422


async def test_unknown_order_number_is_404(client: AsyncClient) -> None:
    assert (await client.get("/api/orders/NIB-000000")).status_code == 404
