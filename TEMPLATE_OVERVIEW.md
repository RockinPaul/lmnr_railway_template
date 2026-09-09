# Deploy and Host Laminar on Railway

[Laminar](https://github.com/lmnr-ai/lmnr) is an open-source observability and
evaluation platform for LLM applications. It ingests OpenTelemetry traces from
your agents, stores them in ClickHouse, and gives you a UI to search, inspect,
tag and evaluate them, alongside a SQL query engine over your own trace data.

## About Hosting Laminar

Laminar is four cooperating services, and this template runs and wires all of
them: the Next.js web app, the Rust API server that accepts OpenTelemetry and
answers queries, ClickHouse for spans and traces, and PostgreSQL for projects,
users and API keys. It runs Laminar's `LITE` configuration, which removes the
runtime dependency on RabbitMQ, Redis and Quickwit, so four services cover it
instead of seven. The web app applies both databases' schema migrations on its
first boot, so there is no migration step to run. Both data stores stay on
Railway's private network with a volume each, every secret is generated, and
the two public services get their own HTTPS domain.

Two things are specific to hosting it. Laminar's API server binds IPv4 only on
all of its ports while Railway's private network is IPv6, so its wrapper runs
two small bridges that let the web app reach the API and the realtime stream
privately. And Laminar's realtime endpoint has no authentication of its own,
because upstream expects the web app in front of it to provide that, so this
template never gives it a public domain.

## Common Use Cases

- Keep traces of your LLM agents and their prompts on infrastructure you own.
- Debug a multi-step agent by reading the full span tree of a single run.
- Query your own trace data with SQL, and evaluate prompt changes against it.

## Dependencies for Laminar Hosting

- ClickHouse for span and trace storage.
- PostgreSQL for projects, users and API keys.
- A GitHub OAuth app, which is required for sign-in.

### Deployment Dependencies

- [Laminar](https://github.com/lmnr-ai/lmnr) — the upstream project (Apache-2.0).
- [Laminar documentation](https://laminar.sh/docs) — SDK setup and the
  self-hosting guide.
- [GitHub OAuth apps](https://github.com/settings/developers) — where the two
  required credentials come from.

### Implementation Details

Four services build from this template's repository, each from its own
directory:

- **frontend** — `ghcr.io/lmnr-ai/frontend:v0.2.4`. Runs the UI and, on boot,
  the PostgreSQL and ClickHouse migrations. Its entrypoint waits for both
  stores so a first deploy does not crash-loop, and refuses to start without
  GitHub OAuth credentials.
- **app-server** — `ghcr.io/lmnr-ai/app-server:v0.2.4`. The OTLP ingest
  endpoint and query API, public on `/v1/traces`. Its wrapper adds `socat`
  bridges giving the IPv4 listeners an IPv6 address on the private network.
- **clickhouse** — `clickhouse/clickhouse-server:26.5`, with upstream's two
  configuration files baked in and an IPv6 listener added.
- **postgres** — `postgres:16`, database and user baked, data in a subdirectory
  of the volume because a Railway volume root holds a root-owned `lost+found`
  that `initdb` refuses.

**Set the GitHub OAuth callback URL after deploying.** Create the OAuth app
first with any placeholder callback, deploy with its client ID and secret, then
set the callback to `https://YOUR-FRONTEND-DOMAIN/api/auth/callback/github`,
using the domain Railway gave the frontend service. This
order matters: with no identity provider configured, Laminar's self-hosted
sign-in accepts any email address with no password, so the template refuses to
start rather than come up open.

Full-text span search is the one feature `LITE` mode gives up, because it is
backed by Quickwit. The SQL query engine over ClickHouse is unaffected.

## Why Deploy Laminar on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway
will host your infrastructure so you don't have to deal with configuration,
while allowing you to vertically and horizontally scale it.

By deploying Laminar on Railway, you are one step closer to supporting a
complete full-stack application with minimal burden. Host your servers,
databases, AI agents, and more on Railway.
