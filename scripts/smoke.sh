#!/usr/bin/env bash
# End-to-end check against a running stack: browse the catalogue, fill a cart,
# check out, and read the order back. Used by CI and handy after a deploy.
#
#   ./scripts/smoke.sh http://localhost:8080
#   ./scripts/smoke.sh https://shop.example.com

set -euo pipefail

BASE="${1:-http://localhost:8080}"
API="${BASE%/}/api"

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

say "health"
curl -fsS "$API/health" >/dev/null || die "health check failed"

say "readiness (database reachable)"
curl -fsS "$API/health/ready" | json 'd["database"]["reachable"]' | grep -q True \
  || die "database is not reachable"

say "meta"
curl -fsS "$API/meta" | json '"%s %s on %s / %s" % (d["service"], d["version"], d["environment"], d["region"])'

say "catalogue"
TOTAL=$(curl -fsS "$API/products?page_size=1" | json 'd["total"]')
[ "$TOTAL" -gt 0 ] || die "catalogue is empty - did seeding run?"
echo "    $TOTAL products"

SLUG=$(curl -fsS "$API/products?sort=price_asc&in_stock=true&page_size=1" | json 'd["items"][0]["slug"]')
PRODUCT=$(curl -fsS "$API/products/$SLUG")
PRODUCT_ID=$(echo "$PRODUCT" | json 'd["id"]')
PRICE=$(echo "$PRODUCT" | json 'd["price_cents"]')
echo "    cheapest in stock: $SLUG ($PRICE cents)"

say "create a cart"
CART=$(curl -fsS -X POST "$API/carts" | json 'd["id"]')
echo "    cart $CART"

say "add two of $SLUG"
SUBTOTAL=$(curl -fsS -X POST "$API/carts/$CART/items" \
  -H 'Content-Type: application/json' \
  -d "{\"product_id\": $PRODUCT_ID, \"quantity\": 2}" | json 'd["subtotal_cents"]')
[ "$SUBTOTAL" -eq $((PRICE * 2)) ] || die "subtotal $SUBTOTAL != $((PRICE * 2))"

say "check out"
ORDER=$(curl -fsS -X POST "$API/orders" -H 'Content-Type: application/json' -d "{
  \"cart_id\": \"$CART\",
  \"customer_name\": \"Smoke Test\",
  \"email\": \"smoke@example.com\",
  \"address\": \"1 Chalk Lane\",
  \"city\": \"Sheffield\",
  \"postal_code\": \"S1 2HH\",
  \"country\": \"United Kingdom\",
  \"note\": \"automated smoke test\"
}")
NUMBER=$(echo "$ORDER" | json 'd["number"]')
echo "    order $NUMBER"

say "read the order back"
curl -fsS "$API/orders/$NUMBER" | json 'd["number"]' | grep -q "$NUMBER" || die "order not readable"

say "the cart was consumed"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$API/carts/$CART")
[ "$CODE" = "404" ] || die "cart still exists (HTTP $CODE)"

say "the SPA shell is served"
curl -fsS "$BASE/" | grep -qi '<div id="root">' || die "index.html did not come back"

say "deep links fall back to the SPA"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/order/$NUMBER")
[ "$CODE" = "200" ] || die "deep link returned HTTP $CODE"

printf '\033[32mOK\033[0m  every check passed against %s\n' "$BASE"
