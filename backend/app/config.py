"""Application settings, read from the environment (12-factor).

Only the database URL is really required; everything else has a sane default so
`docker compose up` and `pytest` both work with no configuration at all.
"""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- database -------------------------------------------------------
    # In AWS this points at the RDS Postgres endpoint; the password half is
    # expected to arrive from Secrets Manager as part of the connection string.
    database_url: str = Field(
        default="postgresql+asyncpg://nib:nib@localhost:5432/nibshop",
        description="SQLAlchemy async DSN",
    )
    db_pool_size: int = 5
    db_max_overflow: int = 5
    db_echo: bool = False

    # --- http -----------------------------------------------------------
    # CloudFront serves the SPA from its own origin, so the API must allow it.
    cors_origins: str = "*"
    root_path: str = ""

    # --- catalog behaviour ----------------------------------------------
    shipping_flat_cents: int = 1200
    free_shipping_threshold_cents: int = 15000
    seed_on_startup: bool = True

    # --- deployment identity (surfaced by /api/meta) --------------------
    app_version: str = "0.1.0"
    git_sha: str = "dev"
    environment: str = "local"
    aws_region: str = ""

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")


@lru_cache
def get_settings() -> Settings:
    return Settings()
