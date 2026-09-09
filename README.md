# Laminar on Railway

Self-host [Laminar](https://github.com/lmnr-ai/lmnr), an open-source
observability and evaluation platform for LLM applications. It collects
OpenTelemetry traces from your agents, stores them in ClickHouse, and gives you
a UI to search, inspect and evaluate them.

This template runs Laminar's `LITE` configuration: four services, no message
broker, no Redis.

## What gets deployed

| Service | Image | Public | Purpose |
|---|---|---|---|
| `frontend` | `ghcr.io/lmnr-ai/frontend:v0.2.4` | yes | Web UI, auth, and the schema migrations |
| `app-server` | `ghcr.io/lmnr-ai/app-server:v0.2.4` | yes | OTLP ingest endpoint and the query API |
| `clickhouse` | `clickhouse/clickhouse-server:26.5` | no | Span and trace storage |
| `postgres` | `postgres:16` | no | Projects, users, API keys |

All four are thin wrappers over the upstream images. The wrappers bake in the
settings that are fixed for Railway, add an IPv6 bridge that Laminar's API
server needs, and carry the two ClickHouse configuration files that upstream's
compose file bind-mounts.

## Before you deploy: create a GitHub OAuth app

**This template will not start without GitHub OAuth credentials, and that is
deliberate.** With no identity provider configured, Laminar's self-hosted
sign-in page accepts *any* email address with *no* password. On a public URL
that means anyone who finds it can sign in as anyone.

1. Go to <https://github.com/settings/developers> and click **New OAuth App**.
2. Put anything in the callback URL for now, for example
   `https://example.com/api/auth/callback/github`. You will correct it in a
   moment, once Railway has given you a domain.
3. Copy the **Client ID** and generate a **Client Secret**.
4. Deploy this template, pasting both into `AUTH_GITHUB_ID` and
   `AUTH_GITHUB_SECRET`.
5. When the deploy finishes, copy the `frontend` service's domain and set the
   OAuth app's callback URL to `https://<your-domain>/api/auth/callback/github`.

Sign-in works from step 5 onwards. Until then the deployment is running but
nobody can log in, which is the safe way round.

## First run

The first boot takes a few minutes. The `frontend` service applies the
PostgreSQL migrations, then about sixty ClickHouse migrations, then downloads a
model-price table, so give it time before assuming something is wrong. The
other services wait for their stores rather than crash-looping.

Once it is up:

1. Open the `frontend` service's URL and sign in with GitHub.
2. Create a workspace and a project.
3. Copy a project API key from the project's settings.
4. Point your application at the `app-server` service's URL. With the Laminar
   SDK that means setting the base URL and the API key; the SDK sends
   OpenTelemetry over HTTP, which is what this deployment accepts.

## Variables

Everything except the two GitHub values is wired for you with Railway service
references and generated secrets.

| Variable | Service | Default | Purpose |
|---|---|---|---|
| `AUTH_GITHUB_ID` | `frontend` | none, required | GitHub OAuth app client ID |
| `AUTH_GITHUB_SECRET` | `frontend` | none, required | GitHub OAuth app client secret |
| `ALLOW_PASSWORDLESS_SIGNIN` | `frontend` | unset | Set to `true` to run without GitHub OAuth and accept that anyone with the URL can sign in |
| `AEAD_SECRET_KEY` | `app-server` | generated | 64 hex characters. Encrypts stored provider keys. Changing it makes existing ones unreadable |
| `SHARED_SECRET_TOKEN` | `app-server` | generated | Authenticates the frontend to the API server |
| `NEXTAUTH_SECRET` | `frontend` | generated | Signs session cookies |

To turn on the AI features in the UI, such as chat-with-trace and
SQL-with-AI, set `LLM_PROVIDER` and `LLM_API_KEY` on the `frontend` service.
Laminar also sends anonymous self-hosted usage statistics; set
`TELEMETRY_DISABLED=true` on the `frontend` service to opt out.

## How it fits together

- The browser talks to `frontend` over HTTPS. Your applications send traces to
  `app-server` over HTTPS.
- `app-server` binds IPv4 only on all of its ports, while Railway's private
  network is IPv6. Its wrapper runs two small `socat` bridges so the frontend
  can reach the API on private port 8100 and the realtime stream on 8102. Both
  restart themselves if they ever exit.
- The realtime stream has **no authentication of its own**; upstream expects the
  Next.js layer in front of it to do that. It is therefore only ever reachable
  over the private network in this template, never from the internet.
- `postgres` and `clickhouse` have no public domains at all.
- Both stores keep their data on volumes and survive redeploys. PostgreSQL
  writes to a subdirectory of its mount point, because a Railway volume root
  holds a root-owned `lost+found` that `initdb` refuses to accept.
- The `frontend` healthcheck is `/api/auth/ok`, which returns a plain 200 and
  proves the app and its auth layer are both up. The site root is not usable
  for this: it answers a redirect to the sign-in page, which the platform
  treats as unhealthy.
- The `frontend` entrypoint exports `HOSTNAME=::` before starting Next.js.
  Railway injects `HOSTNAME` with the container's own hostname at run time,
  which overrides anything the image sets, and Next.js binds whatever it finds
  there. Left alone it binds IPv4 only and the deployment never starts.

## Limitations

- **No full-text span search.** Upstream's search is backed by Quickwit, which
  `LITE` mode leaves out. Everything else, including the SQL query engine over
  ClickHouse, works.
- **Evaluations that call an LLM need a provider key.** Set one in the project
  settings, or the evaluation features stay idle.
- **This is not a small deployment.** ClickHouse and a Rust API server and a
  Next.js app are all always-on, and ClickHouse in particular wants memory.
  Expect it to cost meaningfully more than a single-service template.
- Railway cannot raise the open-file limit that upstream's compose file asks
  ClickHouse for. On a single-node deployment of this size that has not been a
  problem, but it is a difference from running the compose file yourself.

## Component licenses

The wrappers and docs here are MIT licensed, see `LICENSE`. Laminar is
Apache-2.0, ClickHouse is Apache-2.0, and PostgreSQL uses the PostgreSQL
license.
