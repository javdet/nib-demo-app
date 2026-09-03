from httpx import AsyncClient


async def test_health_is_cheap(client: AsyncClient) -> None:
    assert (await client.get("/api/health")).json() == {"status": "ok"}


async def test_readiness_reports_the_database(client: AsyncClient) -> None:
    body = (await client.get("/api/health/ready")).json()
    assert body["status"] == "ok"
    assert body["database"]["reachable"] is True


async def test_meta_identifies_the_container_and_database(client: AsyncClient) -> None:
    body = (await client.get("/api/meta")).json()
    assert body["service"] == "nib-shop-api"
    assert body["served_by"]
    assert body["database"]["dialect"] == "sqlite"
    assert body["database"]["reachable"] is True
    assert body["uptime_seconds"] >= 0


async def test_openapi_schema_is_served(client: AsyncClient) -> None:
    schema = (await client.get("/openapi.json")).json()
    assert "/api/products" in schema["paths"]
