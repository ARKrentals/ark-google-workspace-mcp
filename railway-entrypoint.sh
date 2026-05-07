#!/bin/sh
# railway-entrypoint.sh
# Runs as root briefly to fix Railway-volume ownership, then drops to the
# `app` user and exec's the original command. Railway mounts volumes
# root-owned by default, which prevents the non-root app user from
# writing OAuth refresh tokens / FastMCP OAuth-proxy state to /data.
# Without this fix, persisted state silently fails on writes and is
# wiped on every pod restart.
set -e

# Fix volume ownership (idempotent — chown is fast even if already correct).
if [ -d /data ]; then
    chown -R app:app /data
    chmod 755 /data
fi

# Drop to the non-root app user and exec the original CMD string.
# `su -s /bin/sh -c "..." app` runs the command as `app`.
exec su -s /bin/sh -c "$*" app
