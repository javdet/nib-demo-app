#!/bin/sh
# Runs from nginx's /docker-entrypoint.d before the server starts.
#
# Writes the runtime config from the environment so one built bundle can point
# at any API origin - the same trick the S3 upload uses in AWS. An empty value
# means "same origin", which is what the compose stack and CloudFront both want.
set -e

cat > /usr/share/nginx/html/config.json <<JSON
{
  "apiBaseUrl": "${API_BASE_URL:-}"
}
JSON

echo "runtime config: apiBaseUrl=${API_BASE_URL:-<same-origin>}"
