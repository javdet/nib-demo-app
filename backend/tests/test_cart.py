from httpx import AsyncClient


async def test_new_cart_is_empty(client: AsyncClient, cart_id: str) -> None:
    body = (await client.get(f"/api/carts/{cart_id}")).json()
    assert body["items"] == []
    assert body["subtotal_cents"] == 0
    assert body["shipping_cents"] == 0  # nothing to ship


async def test_add_item_accumulates_quantity(client: AsyncClient, cart_id, product) -> None:
    await client.post(f"/api/carts/{cart_id}/items", json={"product_id": product["id"]})
    body = (
        await client.post(
            f"/api/carts/{cart_id}/items", json={"product_id": product["id"], "quantity": 2}
        )
    ).json()

    assert len(body["items"]) == 1
    assert body["items"][0]["quantity"] == 3
    assert body["item_count"] == 3
    assert body["subtotal_cents"] == product["price_cents"] * 3


async def test_shipping_is_free_above_the_threshold(client: AsyncClient, cart_id, product) -> None:
    body = (
        await client.post(
            f"/api/carts/{cart_id}/items", json={"product_id": product["id"], "quantity": 1}
        )
    ).json()
    assert body["subtotal_cents"] < body["free_shipping_threshold_cents"]
    assert body["shipping_cents"] == 1200
    assert body["total_cents"] == body["subtotal_cents"] + 1200

    body = (
        await client.post(
            f"/api/carts/{cart_id}/items", json={"product_id": product["id"], "quantity": 1}
        )
    ).json()
    assert body["subtotal_cents"] >= body["free_shipping_threshold_cents"]
    assert body["shipping_cents"] == 0


async def test_quantity_update_and_zero_removes(client: AsyncClient, cart_id, product) -> None:
    body = (
        await client.post(f"/api/carts/{cart_id}/items", json={"product_id": product["id"]})
    ).json()
    item_id = body["items"][0]["id"]

    body = (
        await client.patch(f"/api/carts/{cart_id}/items/{item_id}", json={"quantity": 4})
    ).json()
    assert body["items"][0]["quantity"] == 4

    body = (
        await client.patch(f"/api/carts/{cart_id}/items/{item_id}", json={"quantity": 0})
    ).json()
    assert body["items"] == []


async def test_delete_item(client: AsyncClient, cart_id, product) -> None:
    body = (
        await client.post(f"/api/carts/{cart_id}/items", json={"product_id": product["id"]})
    ).json()
    item_id = body["items"][0]["id"]

    body = (await client.delete(f"/api/carts/{cart_id}/items/{item_id}")).json()
    assert body["items"] == []


async def test_cannot_add_more_than_stock(client: AsyncClient, cart_id) -> None:
    xl = (await client.get("/api/products/studio-slate-xl")).json()
    response = await client.post(
        f"/api/carts/{cart_id}/items", json={"product_id": xl["id"], "quantity": 99}
    )
    assert response.status_code == 409
    assert "left in stock" in response.json()["detail"]


async def test_unknown_cart_and_product_are_404(client: AsyncClient, cart_id, product) -> None:
    assert (await client.get("/api/carts/does-not-exist")).status_code == 404
    response = await client.post(f"/api/carts/{cart_id}/items", json={"product_id": 99999})
    assert response.status_code == 404
