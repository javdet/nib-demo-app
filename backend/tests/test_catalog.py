from httpx import AsyncClient


async def test_categories_are_seeded_in_order(client: AsyncClient) -> None:
    response = await client.get("/api/categories")
    assert response.status_code == 200
    slugs = [c["slug"] for c in response.json()]
    assert slugs[:3] == ["chalkboards", "whiteboards", "glass-boards"]


async def test_product_listing_is_paginated(client: AsyncClient) -> None:
    response = await client.get("/api/products", params={"page_size": 5})
    body = response.json()
    assert response.status_code == 200
    assert len(body["items"]) == 5
    assert body["total"] == 20
    assert body["pages"] == 4


async def test_featured_sort_puts_featured_first(client: AsyncClient) -> None:
    body = (await client.get("/api/products", params={"sort": "featured"})).json()
    assert body["items"][0]["featured"] is True


async def test_price_sort(client: AsyncClient) -> None:
    body = (await client.get("/api/products", params={"sort": "price_asc"})).json()
    prices = [p["price_cents"] for p in body["items"]]
    assert prices == sorted(prices)


async def test_filter_by_category_and_surface(client: AsyncClient) -> None:
    body = (await client.get("/api/products", params={"category": "cork"})).json()
    assert body["total"] == 2
    assert {p["category"]["slug"] for p in body["items"]} == {"cork"}

    body = (await client.get("/api/products", params={"surface": "glass"})).json()
    assert {p["surface"] for p in body["items"]} == {"glass"}


async def test_search_matches_description_text(client: AsyncClient) -> None:
    body = (await client.get("/api/products", params={"q": "porcelain"})).json()
    slugs = {p["slug"] for p in body["items"]}
    assert "nib-dry-erase-1200" in slugs


async def test_unknown_product_is_404(client: AsyncClient) -> None:
    assert (await client.get("/api/products/no-such-board")).status_code == 404


async def test_seeding_twice_does_not_duplicate(sessionmaker_) -> None:
    from sqlalchemy import func, select

    from app.models import Product
    from app.seed import seed_catalog

    async with sessionmaker_() as session:
        await seed_catalog(session)
        await seed_catalog(session)
        total = await session.scalar(select(func.count(Product.id)))
    assert total == 20
