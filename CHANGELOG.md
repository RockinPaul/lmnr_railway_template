# Changelog

## 2026-09-09

Initial release.

- Four services: `frontend`, `app-server`, `clickhouse`, `postgres`, each built
  from its own directory in this repository.
- Pinned to Laminar `v0.2.4`, ClickHouse `26.5` and PostgreSQL `16`.
- Runs in Laminar's `LITE` mode, so RabbitMQ, Redis and Quickwit are not
  required. Full-text span search is the feature this gives up.
- The `app-server` wrapper adds an IPv6 bridge, because the upstream server
  binds IPv4 only and Railway's private network is IPv6.
- The `clickhouse` wrapper bakes in upstream's two configuration files, which
  its compose file bind-mounts, plus an IPv6 listener.
- The `frontend` wrapper waits for both stores before starting, so a first
  deploy does not crash-loop while they come up, and refuses to start with
  passwordless sign-in unless that is explicitly allowed.
- GitHub OAuth credentials are required. Without an identity provider,
  Laminar's self-hosted sign-in accepts any email address with no password.
- The `frontend` entrypoint exports `HOSTNAME=::` so Next.js binds IPv6.
  Railway injects `HOSTNAME` at run time and it overrides the image's ENV, so
  this cannot be set in the Dockerfile.
- The `frontend` healthcheck is `/api/auth/ok`. The site root redirects to the
  sign-in page, and Railway's healthcheck counts a redirect as a failure.
