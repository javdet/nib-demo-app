#!/bin/sh
# Apply migrations before serving. Concurrent tasks starting together are safe:
# Alembic takes a lock on alembic_version, so the losers no-op.
set -e

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "==> alembic upgrade head"
  alembic upgrade head
fi

exec "$@"
