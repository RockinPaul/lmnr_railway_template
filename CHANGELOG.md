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
- Published to the Railway marketplace as `laminar` under Observability.
  The marketplace overview avoids `<angle-bracket>` placeholders: the publish
  pipeline strips them as HTML, even inside backticks, which silently turned a
  callback URL into `https:///api/auth/callback/github`.

## 2026-09-09, later

Two changes after review.

- **Added a fifth service, `quickwit`,** restoring full-text search over prompts
  and completions. Without it the search box returned no results silently: the
  lookup failed and the frontend swallowed the error, so it read as "no
  matches" rather than "search is off".
- **The frontend now carries Laminar's Quickwit index definitions.** The
  published image copies `lib/db/migrations` and `lib/clickhouse/migrations`
  into its standalone output but not `lib/quickwit/indexes`, so upstream's own
  startup code logged "Quickwit indexes directory not found" and created
  nothing. The three files are vendored at the same tag as the image; see
  `frontend/quickwit-indexes/README.md` before bumping it.
- **The sign-in guard now accepts any of Laminar's five identity providers,**
  not just GitHub. Previously a team on Google Workspace or Okta had to set
  `ALLOW_PASSWORDLESS_SIGNIN=true` to get past the check, which read as opting
  into an open deployment when they had a perfectly good provider configured.
  The variable groups mirror upstream's own checks, so a partial group (two of
  Okta's three values) is correctly treated as not configured.
- **The app-server now waits for Quickwit before starting.** It connects once
  at boot and, on failure, logs "Quickwit not available - skipping spans
  indexer workers" and never retries, so losing a DNS race against a
  sibling service disabled search for the life of the container.
