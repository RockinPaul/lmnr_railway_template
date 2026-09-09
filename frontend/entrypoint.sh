#!/bin/sh
# Check the wiring, wait for the stores, then start Next.js.
#
# This service runs the schema migrations for both Postgres and ClickHouse
# during startup, and throws if ClickHouse is not there yet. Waiting turns a
# first-boot crash loop into a slightly slower first boot.
set -eu

require() {
  eval "value=\${$1:-}"
  if [ -z "$value" ]; then
    echo "$1 is empty; the template's service references did not resolve" >&2
    exit 1
  fi
}

require DATABASE_URL
require CLICKHOUSE_URL
require CLICKHOUSE_PASSWORD
require BACKEND_URL
require BACKEND_RT_URL
require SHARED_SECRET_TOKEN
require AEAD_SECRET_KEY
require NEXTAUTH_URL
require NEXTAUTH_SECRET

case "$AEAD_SECRET_KEY" in
  *[!0-9a-fA-F]* | "")
    echo "AEAD_SECRET_KEY must be exactly 64 hexadecimal characters (32 bytes)" >&2
    exit 1 ;;
esac
if [ "${#AEAD_SECRET_KEY}" -ne 64 ]; then
  echo "AEAD_SECRET_KEY must be exactly 64 hexadecimal characters (32 bytes)" >&2
  exit 1
fi

# Without an identity provider the sign-in page accepts any email address with
# no password, which is not acceptable on a public URL. Refuse to start rather
# than come up wide open.
#
# Any one of the five providers Laminar supports closes that hole, and the
# variable groups below mirror its own checks exactly (lib/features/features.ts),
# so configuring Google, Azure, Okta or Keycloak is just as good as GitHub and
# the GitHub variables can be removed.
provider=""
set_provider() {
  [ -n "$provider" ] || provider="$1"
}
if [ -n "${AUTH_GITHUB_ID:-}" ] && [ -n "${AUTH_GITHUB_SECRET:-}" ]; then
  set_provider "GitHub"
fi
if [ -n "${AUTH_GOOGLE_ID:-}" ] && [ -n "${AUTH_GOOGLE_SECRET:-}" ]; then
  set_provider "Google"
fi
if [ -n "${AUTH_AZURE_AD_CLIENT_ID:-}" ] && [ -n "${AUTH_AZURE_AD_CLIENT_SECRET:-}" ] \
  && [ -n "${AUTH_AZURE_AD_TENANT_ID:-}" ]; then
  set_provider "Azure AD"
fi
if [ -n "${AUTH_OKTA_CLIENT_ID:-}" ] && [ -n "${AUTH_OKTA_CLIENT_SECRET:-}" ] \
  && [ -n "${AUTH_OKTA_ISSUER:-}" ]; then
  set_provider "Okta"
fi
if [ -n "${AUTH_KEYCLOAK_ID:-}" ] && [ -n "${AUTH_KEYCLOAK_SECRET:-}" ] \
  && [ -n "${AUTH_KEYCLOAK_ISSUER:-}" ]; then
  set_provider "Keycloak"
fi

if [ -n "$provider" ]; then
  echo "sign-in provider configured: $provider"
else
  if [ "${ALLOW_PASSWORDLESS_SIGNIN:-}" != "true" ]; then
    echo "No identity provider is configured." >&2
    echo "Laminar's self-hosted sign-in accepts ANY email with no password when no" >&2
    echo "identity provider is configured, so this deployment would be open to anyone" >&2
    echo "who finds its URL. Set one of these groups of variables:" >&2
    echo "  AUTH_GITHUB_ID + AUTH_GITHUB_SECRET" >&2
    echo "  AUTH_GOOGLE_ID + AUTH_GOOGLE_SECRET" >&2
    echo "  AUTH_AZURE_AD_CLIENT_ID + AUTH_AZURE_AD_CLIENT_SECRET + AUTH_AZURE_AD_TENANT_ID" >&2
    echo "  AUTH_OKTA_CLIENT_ID + AUTH_OKTA_CLIENT_SECRET + AUTH_OKTA_ISSUER" >&2
    echo "  AUTH_KEYCLOAK_ID + AUTH_KEYCLOAK_SECRET + AUTH_KEYCLOAK_ISSUER" >&2
    echo "To accept that risk deliberately, set ALLOW_PASSWORDLESS_SIGNIN=true." >&2
    exit 1
  fi
  echo "WARNING: starting with passwordless sign-in; anyone with the URL can sign in" >&2
fi

node /railway-wait-for-deps.mjs

# Next.js reads its bind address from HOSTNAME, and both Docker and Railway
# inject HOSTNAME with the container's own hostname at run time, which beats
# anything ENV sets in the image. Export it here, after that injection, so the
# listener is on the IPv6 wildcard: Railway does not consider a service started
# until it sees an IPv6 listener, and an IPv4-only bind leaves the deployment
# stuck in "deploying" forever. On Linux this socket is dual-stack, so the
# public edge still reaches it over IPv4.
export HOSTNAME="${NEXT_BIND_HOST:-::}"

# No "$@": the upstream image's CMD is ["node","server.js"], and Docker passes
# CMD as arguments to an overridden ENTRYPOINT, which would duplicate it.
exec node server.js
