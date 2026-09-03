# CLAUDE.md

Guidance for Claude Code working in this repository.

## Project

**Nib & Slate** — a demo storefront (chalkboards and other drawing surfaces) whose purpose is to
demonstrate a deployment: React SPA on S3/CloudFront, FastAPI on ECS Fargate, Postgres on RDS. The
store is the vehicle; the `/deployment` page is the point. Sibling of the `nib` repo, which is a
separate Go+React project — do not confuse the two.

## Commands

Docker is the only hard requirement; a Python venv and node_modules are created on demand by the
`test-*` targets.

```bash
make up                                    # full stack -> :8080
make dev && make web                       # reloading API on :8000 + vite on :5173
make test                                  # pytest + vitest + tsc + eslint
./scripts/smoke.sh http://localhost:8080   # end-to-end against a running stack
```

Single suites:

```bash
cd backend  && .venv/bin/python -m pytest tests/test_cart.py -v
cd frontend && npm run test -- src/lib/format.test.ts
```

Port 8080 is often taken on a dev machine; `WEB_PORT=8088 docker compose up -d` moves it.

## Things worth knowing before editing

- **Models must stay dialect-neutral.** The test suite runs on in-memory SQLite while production
  is Postgres, so money is integer cents and ids that reach the browser are `String(36)` UUIDs.
  Adding a Postgres-only column type breaks the whole suite, not one test.
- **Migrations are hand-written and checked.** After changing `app/models.py`, generate a revision
  and run `alembic check` — CI fails on drift. Watch for `unique=True, index=True` on a column:
  SQLAlchemy renders that as a *unique index*, not a unique constraint plus an index, and the
  migration has to match.
- **Async relationships need eager loading.** Every relationship traversed during serialization is
  `lazy="selectin"`; `Category.products` is `lazy="raise"` on purpose, to turn an accidental lazy
  load into an error instead of a hang.
- **After mutating a cart, re-read it.** `_reload()` in `routers/cart.py` re-fetches with
  `populate_existing=True` so the eager loaders see the change; serializing the stale instance
  silently returns the pre-mutation totals.
- **The frontend has no data-fetching library.** `useAsync` in `src/lib/useAsync.ts` is the whole
  of it, and the cart is a context in `src/lib/cart.tsx`. Do not reach for TanStack Query for one
  more screen.
- **Product artwork is generated SVG**, seeded from the product slug (`components/BoardArt.tsx`).
  There are no image assets and there should not be.
- **`/config.json` is runtime config**, read before the first render. The API origin is never
  baked into the bundle.

## Not here yet

The Terraform for CloudFront, ECS and RDS is the next piece of work; the README's *Deploying to
AWS* section records what the application already assumes so the two fit together.
