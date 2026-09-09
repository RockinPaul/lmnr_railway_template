#!/bin/bash
# Bridge the server's IPv4-only listeners onto IPv6, then start it.
#
# app-server calls .bind(("0.0.0.0", port)) for its HTTP, gRPC and realtime
# ports, so nothing reaches it over Railway's IPv6 private network. socat gives
# the two ports the frontend needs an IPv6 listener that forwards to the local
# IPv4 one. The public domain still points straight at PORT, which works
# because Railway's public edge reaches the container over IPv4.
set -euo pipefail

require() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "$name is empty; the template's service references did not resolve" >&2
    exit 1
  fi
}

require DATABASE_URL
require CLICKHOUSE_URL
require CLICKHOUSE_PASSWORD
require SHARED_SECRET_TOKEN
require AEAD_SECRET_KEY

# The key is hex-decoded into a 32-byte AEAD key; a wrong length or a non-hex
# character fails deep inside encryption rather than at boot, so check it here.
if ! printf '%s' "$AEAD_SECRET_KEY" | grep -Eq '^[0-9a-fA-F]{64}$'; then
  echo "AEAD_SECRET_KEY must be exactly 64 hexadecimal characters (32 bytes)" >&2
  exit 1
fi

# Wait for the stores so the first boot of a fresh deployment does not
# crash-loop while Postgres runs initdb and ClickHouse starts up.
wait_for() {
  local host="$1" port="$2" label="$3" waited=0
  until (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; do
    if [ "$waited" -ge 180 ]; then
      echo "timed out after ${waited}s waiting for $label at $host:$port" >&2
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  exec 3>&- 2>/dev/null || true
  echo "$label is accepting connections at $host:$port"
}

# Hosts come out of the URLs the template wired, so nothing has to be repeated
# as its own variable.
pg_host=$(printf '%s' "$DATABASE_URL" | sed -E 's|^[^@]*@||; s|[:/].*$||')
pg_port=$(printf '%s' "$DATABASE_URL" | sed -nE 's|^[^@]*@[^:/]+:([0-9]+).*$|\1|p')
ch_host=$(printf '%s' "$CLICKHOUSE_URL" | sed -E 's|^https?://||; s|[:/].*$||')
ch_port=$(printf '%s' "$CLICKHOUSE_URL" | sed -nE 's|^https?://[^:/]+:([0-9]+).*$|\1|p')
wait_for "$pg_host" "${pg_port:-5432}" "postgres"
wait_for "$ch_host" "${ch_port:-8123}" "clickhouse"

# Quickwit matters more than the other two, because the server tries to connect
# exactly ONCE at boot and, on failure, logs "Quickwit not available - skipping
# spans indexer workers" and never retries. Racing its DNS entry therefore
# disables full-text search for the whole life of the container, silently: the
# search box just returns nothing.
if [ -n "${QUICKWIT_SEARCH_URL:-}" ]; then
  qw_host=$(printf '%s' "$QUICKWIT_SEARCH_URL" | sed -E 's|^https?://||; s|[:/].*$||')
  qw_port=$(printf '%s' "$QUICKWIT_SEARCH_URL" | sed -nE 's|^https?://[^:/]+:([0-9]+).*$|\1|p')
  wait_for "$qw_host" "${qw_port:-7280}" "quickwit (search)"
fi
if [ -n "${QUICKWIT_INGEST_URL:-}" ]; then
  qwi_host=$(printf '%s' "$QUICKWIT_INGEST_URL" | sed -E 's|^https?://||; s|[:/].*$||')
  qwi_port=$(printf '%s' "$QUICKWIT_INGEST_URL" | sed -nE 's|^https?://[^:/]+:([0-9]+).*$|\1|p')
  wait_for "$qwi_host" "${qwi_port:-7281}" "quickwit (ingest)"
fi

# Restart a bridge if it ever exits, so a transient failure does not silently
# cut the frontend off from the API for the life of the container.
bridge() {
  local listen="$1" target="$2"
  while true; do
    socat -d0 "TCP6-LISTEN:${listen},fork,reuseaddr" "TCP4:127.0.0.1:${target}" || true
    echo "socat bridge ${listen} -> ${target} exited; restarting" >&2
    sleep 1
  done
}

bridge "${IPV6_HTTP_PORT:-8100}" "${PORT:-8080}" &
bridge "${IPV6_REALTIME_PORT:-8102}" "${CONSUMER_PORT:-8002}" &
echo "IPv6 bridges listening on ${IPV6_HTTP_PORT:-8100} (http) and ${IPV6_REALTIME_PORT:-8102} (realtime)"

exec ./app-server "$@"
