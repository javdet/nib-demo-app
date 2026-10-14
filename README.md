# Nib & Slate

A demo storefront selling chalkboards, whiteboards and other drawing surfaces — built to
demonstrate a deployment, not a business. A React SPA talks to a containerised Python API, which
talks to Postgres; the store is what makes that path visible and worth clicking through.

The site says so itself: **How it's deployed** in the header renders the request path and a live
panel naming the container and the database that answered the page you are looking at.

```
React SPA (Vite)  ->  CloudFront + S3  ->  ALB  ->  ECS Fargate (FastAPI)  ->  RDS Postgres
```

Locally the same shape is reproduced with nginx standing in for CloudFront, a compose service for
Fargate, and a Postgres container for RDS — so the browser makes same-origin requests in both
places and nothing behaves differently for want of a proxy.

## Quick start

Everything runs in Docker; nothing needs to be installed on the host.

```bash
make up          # build and start db + api + web
open http://localhost:8080
```

| URL                            | What it is                             |
| ------------------------------ | -------------------------------------- |
| http://localhost:8080          | The store                              |
| http://localhost:8080/deployment | The "how it's deployed" page         |
| http://localhost:8000/docs     | OpenAPI docs for the API               |
| localhost:5433                 | Postgres (`nib` / `nib` / `nibshop`)   |

`make down` stops it, `make clean` also drops the database volume. Ports are configurable — see
[.env.example](.env.example) — which matters if something already owns 8080.

### Working on the code

```bash
make dev         # Postgres + the API on :8000, reloading on save
make web         # Vite dev server on :5173, proxying /api to :8000
```

```bash
make test        # pytest + vitest + tsc + eslint
./scripts/smoke.sh http://localhost:8080   # end-to-end against a running stack
```

## Layout

```
backend/            FastAPI + SQLAlchemy 2.0 (async) + Alembic
  app/routers/      catalog, cart, orders, system (health & meta)
  app/services.py   pricing and checkout rules
  app/data/         the seed catalogue, as Python
  alembic/          migrations, applied by the container at startup
  tests/            pytest against in-memory SQLite - no services required
frontend/           React 19 + TypeScript + Vite, no UI framework
  src/lib/          api client, cart context, runtime config
  src/components/   layout, product artwork, architecture diagram
  src/pages/        catalog, product, cart, checkout, order, deployment
infra/terraform/    prod AWS infrastructure (VPC, ECS, RDS, CloudFront, ...)
scripts/smoke.sh    end-to-end check against a deployed stack
```

## How it works

**Carts live in Postgres.** The browser stores one cart id in `localStorage` and nothing else;
quantities, prices and stock are all resolved server-side on every mutation. That is deliberate —
it means a page reload, a second tab, or a Fargate task being replaced mid-session all behave
correctly, and it gives the demo a reason to write to the database rather than just read from it.

**Checkout consumes the cart.** Placing an order copies product names and prices into
`order_items` (so an order still reads correctly after a re-price), decrements stock, and deletes
the cart, which makes a stale cart id impossible to check out twice.

**Product images are drawn, not photographed.** Every board is an SVG generated from the
product's surface, dimensions and accent colour, with scribbles seeded from its slug — so the
catalogue has no binary assets to store, upload or cache-bust.

**Runtime configuration, not build-time.** The bundle is built once and reads `/config.json` at
boot to find its API origin. Empty means same-origin, which is what both nginx and CloudFront
serve. The nginx image writes that file from `$API_BASE_URL` on start; in AWS it is uploaded
alongside the bundle.

**`/api/meta` is the interesting endpoint.** It reports the version, the git sha, the region, the
container that handled the request and a live round trip to the database. With more than one task
behind the load balancer, hitting "Ask again" on the deployment page shows the request landing on
different containers.

## API

Everything is under `/api`. Full schema at `/docs`.

| Method   | Path                              | Purpose                              |
| -------- | --------------------------------- | ------------------------------------ |
| `GET`    | `/health`                         | Liveness. Touches nothing.           |
| `GET`    | `/health/ready`                   | Readiness. 503 if the DB is down.    |
| `GET`    | `/meta`                           | Deployment identity and DB latency   |
| `GET`    | `/categories`                     | All categories, in display order     |
| `GET`    | `/products`                       | Filter, search, sort, paginate       |
| `GET`    | `/products/{slug}`                | One product                          |
| `POST`   | `/carts`                          | Create an empty cart                 |
| `GET`    | `/carts/{id}`                     | Read a cart with totals              |
| `POST`   | `/carts/{id}/items`               | Add a product (accumulates)          |
| `PATCH`  | `/carts/{id}/items/{item_id}`     | Set quantity; `0` removes            |
| `DELETE` | `/carts/{id}/items/{item_id}`     | Remove a line                        |
| `POST`   | `/orders`                         | Check a cart out                     |
| `GET`    | `/orders/{number}`                | Read an order back                   |

`GET /products` accepts `category`, `surface`, `q`, `in_stock`, `sort`
(`featured` \| `price_asc` \| `price_desc` \| `name`), `page` and `page_size`.

## Configuration

The API is configured entirely from the environment ([app/config.py](backend/app/config.py)); all
of it has working defaults.

| Variable                        | Default                    | Notes                                    |
| ------------------------------- | -------------------------- | ---------------------------------------- |
| `DATABASE_URL`                  | local Postgres             | Async DSN (`postgresql+asyncpg://…`)     |
| `CORS_ORIGINS`                  | `*`                        | Comma-separated                          |
| `SEED_ON_STARTUP`               | `true`                     | Idempotent; safe to leave on             |
| `RUN_MIGRATIONS`                | `true`                     | `alembic upgrade head` in the entrypoint |
| `SHIPPING_FLAT_CENTS`           | `1200`                     | Free above the threshold                 |
| `FREE_SHIPPING_THRESHOLD_CENTS` | `15000`                    |                                          |
| `APP_VERSION` / `GIT_SHA`       | `0.1.0` / `dev`            | Shown in the footer and `/api/meta`      |
| `ENVIRONMENT` / `AWS_REGION`    | `local` / unset            | Shown in the footer and `/api/meta`      |

The frontend takes `API_BASE_URL` at container start (written into `config.json`) or
`VITE_API_BASE_URL` at build time. Leave both empty for same-origin.

### Database changes

Models live in [backend/app/models.py](backend/app/models.py). After editing them:

```bash
make migration m="add wishlists"   # autogenerate against the dev database
make migrate                       # apply
```

CI runs `alembic check` to fail a build whose migrations have drifted from the models.

## Deploying to AWS

The infrastructure lives in [infra/terraform](infra/terraform) and targets Terraform `1.10.5` with
the `hashicorp/aws` provider pinned to `5.84.0`. State is remote and shared: S3 bucket
`javdet-nib-demo-app-prod-tfstate`, key `prod/terraform.tfstate`, region `us-east-1`, encrypted,
with the S3 backend's native state locking. That bucket, and the OIDC trust described below, are
bootstrapped once, out of band, before this configuration's first `terraform init` — this repo
does not create the thing it stores its own state in.

- **Frontend** — a private S3 bucket (`javdet-nib-demo-app-prod-frontend`) read only by CloudFront
  through an Origin Access Control, with a 403/404 response rewrite to `/index.html` so client-side
  routes survive a hard refresh.
- **API** — `backend/Dockerfile`'s non-root image on ECS Fargate, behind an ALB whose target group
  health check is `/api/health/ready`. The entrypoint runs `alembic upgrade head` before serving;
  concurrent tasks are safe, because Alembic locks `alembic_version` and the losers no-op.
- **Database** — Multi-AZ RDS for PostgreSQL `16` in isolated subnets, reachable only from the
  ECS task security group. `DATABASE_URL` is generated by Terraform, stored only in Secrets
  Manager secret `nib-demo-app/prod/database`, and injected into the task definition as a secret,
  never a plain environment variable.
- **Routing** — one CloudFront distribution with two origins: S3 as the default, and the ALB for
  `/api/*` with caching disabled and the full query string, every method and every cookie
  forwarded. That keeps the SPA and the API on one origin, so there is no CORS to configure and no
  preflight on every request.

**Merging to `main` deploys `prod`.** [.github/workflows/deploy-prod.yml](.github/workflows/deploy-prod.yml)
runs `deploy-infrastructure` then `deploy-application`, each bound independently to the GitHub
Environment `prod` and so each gated on its own required-reviewer approval before it runs. Neither
job holds long-lived AWS credentials: `deploy-infrastructure` assumes
`nib-demo-app-prod-infra-deployer` via the `AWS_INFRA_ROLE_ARN` environment variable,
`deploy-application` assumes `nib-demo-app-prod-app-deployer` via `AWS_APP_ROLE_ARN` — both
variables, and the OIDC trust that lets GitHub Actions assume them, come from the same bootstrap
work that creates the state bucket. A failed or interrupted run can be retried with
`workflow_dispatch`, without waiting for a new commit to `main`.

`deploy-infrastructure` applies the Terraform and publishes exactly six outputs, which
`deploy-application` consumes instead of recomputing: `ecr_repository_url`, `ecs_cluster_name`,
`ecs_service_name`, `frontend_bucket_name`, `cloudfront_distribution_id`, `cloudfront_domain_name`.
The ECS service it creates starts at `desired_count = 0` — infrastructure can land in an account
with no image in ECR yet, and from then on the service's task definition and desired count are the
application job's to manage, not Terraform's. `deploy-application` builds and pushes the backend
image tagged with the commit SHA, registers a new task-definition revision pointing at it, and
scales the service to two tasks with `--force-new-deployment`; it builds the frontend, uploads
fingerprinted `assets/` with an immutable cache header, then `index.html` and `config.json` with
`no-store`, removes assets the new shell no longer references, and invalidates CloudFront.

The site's URL is generated, not fixed — CloudFront assigns the domain name on creation. Read it
from the `cloudfront_domain_name` Terraform output (in the `deploy-infrastructure` job's logs, or
with `terraform output cloudfront_domain_name` against the `prod` state) and run the same check
the deploy's last step runs:

```bash
./scripts/smoke.sh https://<cloudfront_domain_name>
```

**Tearing down is deliberate, not a single `terraform destroy`.** The database has deletion
protection enabled and takes a final snapshot on its way out; both have to be turned off, or the
snapshot explicitly accepted, before Postgres will actually delete. The generated database
password lives only in Secrets Manager and in the (encrypted) state file — destroying the secret
and the state bucket each need their own confirmation, so losing either one is never a side effect
of tearing down everything else.

## Notes

This is a demonstration. There is no payment provider, no authentication, no email, and no
restocking — placing an order decrements stock and that is the end of it. `make clean` puts the
catalogue back.
