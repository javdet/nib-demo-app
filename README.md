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
scripts/smoke.sh    end-to-end check against a deployed stack
infra/              Terraform + the one-time CloudFormation bootstrap - see Deploying to AWS
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

```
React SPA (Vite)  ->  CloudFront + S3  ->  ALB  ->  ECS Fargate (FastAPI)  ->  RDS Postgres
```

- **Frontend** — `npm run build` produces `frontend/dist`. The bucket is private; CloudFront reads
  it through an Origin Access Control, and a 403/404 response rewrite to `/index.html` keeps
  client-side routes working after a hard refresh.
- **API** — `backend/Dockerfile` builds a non-root image listening on 8000, behind an ALB target
  group health-checked at `/api/health/ready`. The entrypoint runs `alembic upgrade head` before
  serving; concurrent tasks are safe, because Alembic locks `alembic_version` and the losers no-op.
- **Database** — RDS for PostgreSQL in isolated subnets, reachable only from the ECS task security
  group. `DATABASE_URL` comes from Secrets Manager as a task-definition secret, never a plain
  environment variable.
- **Routing** — one CloudFront distribution with two origins: S3 as the default, and the ALB for
  `/api/*` with caching disabled and every header, cookie and query string forwarded. That keeps
  the SPA and the API on one origin, so there is no CORS to configure and no preflight on every
  request. The ALB itself only accepts traffic that both arrives from CloudFront's published IP
  ranges and carries a secret header CloudFront injects on every origin request - its public DNS
  name is not a usable back door around the CDN.

### Layout

```
infra/bootstrap/template.yml   One-time CloudFormation: state bucket, lock table, OIDC, deploy role
infra/terraform/                Everything deploy-infrastructure.yml applies
  versions.tf, providers.tf    Terraform 1.16.5, hashicorp/aws 6.68.0, the S3 backend
  variables.tf, locals.tf      Validated inputs and the fixed production topology
  production.tfvars            The one environment's values, spelled out explicitly
  network.tf, security.tf      VPC/subnets/routing; ALB + ECS + RDS security groups
  ecr.tf, database.tf, ecs.tf  The backend's image repo, database, cluster/service
  frontend.tf                  S3 + CloudFront
  outputs.tf                   What deploy-application.yml reads back out
.github/workflows/
  deploy-infrastructure.yml    terraform fmt/validate/plan/apply
  deploy-application.yml       Build, push, sync, register, deploy, invalidate, smoke test
```

### Cost and availability trade-offs

This is a demo, not a production SLA, so the topology trades resilience for a smaller bill:

| Decision                          | Costs you availability because...                          |
| ---------------------------------- | ------------------------------------------------------------ |
| One NAT gateway, not one per AZ    | A NAT-gateway AZ failure takes outbound internet access (ECR pulls, Secrets Manager reads) with it, though the ALB, ECS and RDS keep serving on their own AZ's path. |
| Single-AZ `db.t4g.micro`           | An AZ failure or instance replacement is a real outage, not a failover. Automated backups and point-in-time recovery still apply. |
| One backend task                   | No rolling deploys and no spare capacity if the task dies; ECS replaces it, but there is a gap. |

Two Availability Zones are still used for the VPC's subnet tiers and the ALB, so that upgrade path
(a second NAT gateway, `multi_az = true`, `desired_count = 2`) is a `terraform apply` away, not a
redesign.

### Prerequisites

1. An AWS account (this configuration assumes account `216033279229` in `us-east-1`; adjust
   `infra/bootstrap/template.yml`'s hard-coded names and `infra/terraform/production.tfvars` if
   you fork this against a different one).
2. A GitHub environment named **production** on `javdet/nib-demo-app`, with no secrets - only the
   `AWS_ROLE_ARN` **variable** (not a secret) described below. There are no long-lived AWS
   credentials anywhere in this repository or its GitHub configuration; both workflows assume an
   IAM role over OIDC.
3. Terraform `1.16.5` and the AWS CLI, if you want to run any of this from a workstation instead of
   through the workflows.

### One-time bootstrap

Applied once, by hand, with an administrator's own credentials - everything after this point is
either Terraform or GitHub Actions:

```bash
aws cloudformation deploy \
  --stack-name nib-demo-prod-bootstrap \
  --template-file infra/bootstrap/template.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

This creates the Terraform state bucket (`nib-demo-prod-tfstate-<account-id>`, versioned,
SSE-S3-encrypted, TLS-only), the DynamoDB lock table (`nib-demo-prod-terraform-locks`), the GitHub
OIDC provider (skip with `--parameter-overrides CreateGitHubOidcProvider=false
ExistingGitHubOidcProviderArn=...` if the account already has one - IAM allows only one per URL),
and a deployment role trusted only for
`repo:javdet/nib-demo-app:environment:production`. Read the role ARN back out:

```bash
aws cloudformation describe-stacks --stack-name nib-demo-prod-bootstrap \
  --query "Stacks[0].Outputs[?OutputKey=='DeploymentRoleArn'].OutputValue" --output text
```

Set that as the `AWS_ROLE_ARN` **variable** (Settings → Environments → production → Environment
variables, not Secrets) on the GitHub repository. No value here is a credential, so none of it
needs to be a GitHub secret.

### Workflow order

1. **`deploy-infrastructure`** (`workflow_dispatch`) - `terraform fmt -check`, `validate`, a saved
   `plan` against `production.tfvars`, then `apply` of exactly that plan. Non-sensitive outputs
   (`app_url`, the ECR/ECS/CloudFront identifiers) are printed to the job summary; the database
   secret's ARN is marked sensitive and is never printed anywhere a log can capture it, and the
   password itself is never a Terraform output at all. Run this first, and again whenever
   `infra/terraform` changes.
2. **`deploy-application`** (`workflow_dispatch`) - reads those same outputs straight from
   Terraform state (never hand-copied), builds `backend/Dockerfile`, pushes one immutable image
   tagged with the full commit SHA, builds the frontend and syncs it (hashed assets with long
   `max-age` first, then the HTML shell and `config.json` with `no-store`, then a second sync that
   deletes assets no longer referenced - in that order, so a deploy never serves a new shell
   against chunks that are already gone), registers a new ECS task-definition revision for that
   image, raises the service to its contracted one task, waits for stability, invalidates
   CloudFront, and finally runs `./scripts/smoke.sh` against the live `app_url`. Run this after
   infrastructure exists, and on every application change you want live.

### Recovery

- **Bad application deploy** - re-run `deploy-application` against an earlier commit SHA; the
  previous image tag is still in ECR (the lifecycle policy keeps the most recent 20) and immutable
  tags mean it cannot have been overwritten.
- **Bad infrastructure change** - `terraform plan` against a reverted `infra/terraform` and re-run
  `deploy-infrastructure`; state lives in S3 with versioning on, so a bad `apply` is also
  recoverable by restoring the previous state object version if a revert-and-reapply isn't enough.
- **Lost `AWS_ROLE_ARN` or a rotated OIDC trust** - the bootstrap stack is idempotent
  (`aws cloudformation deploy` again); re-read the output and reset the GitHub environment
  variable.
- **Database restore** - RDS automated backups are retained 7 days with point-in-time recovery;
  restore to a new instance with the AWS CLI or console and repoint `infra/terraform` at it. The
  final snapshot policy means even deleting the instance through Terraform leaves one behind.

`./scripts/smoke.sh https://your-app-url` is the same post-deploy check `deploy-application` runs;
it exercises the catalogue, a cart, a checkout and the SPA fallback against any running stack.

## Notes

This is a demonstration. There is no payment provider, no authentication, no email, and no
restocking — placing an order decrements stock and that is the end of it. `make clean` puts the
catalogue back.
