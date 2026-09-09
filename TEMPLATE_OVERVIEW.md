# Deploy and Host Laminar on Railway

[Laminar](https://github.com/lmnr-ai/lmnr) is an open-source observability and
evaluation platform for LLM applications. It ingests OpenTelemetry traces from
your agents, stores them in ClickHouse, and gives you a UI to search, inspect,
tag and evaluate them, alongside a SQL query engine over your own trace data.

## About Hosting Laminar

Laminar is five cooperating services, and this template runs and wires all of
them: the Next.js web app, the Rust API server that accepts OpenTelemetry and
answers queries, ClickHouse for spans and traces, Quickwit for full-text search
over prompts and completions, and PostgreSQL for projects, users and API keys.
It runs Laminar's `LITE` configuration, which removes the runtime dependency on
RabbitMQ and Redis. The web app applies the schema migrations for both
databases and creates the search indexes on its first boot, so there is no
migration step to run. All three data stores stay on Railway's private network
with a volume each, every secret is generated, and the two public services get
their own HTTPS domain.

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
- Quickwit for full-text search over span content.
- PostgreSQL for projects, users and API keys.
- An OAuth app with one of GitHub, Google, Microsoft Entra ID, Okta or
  Keycloak, which is required for sign-in.

### Deployment Dependencies

- [Laminar](https://github.com/lmnr-ai/lmnr) — the upstream project (Apache-2.0).
- [Laminar documentation](https://laminar.sh/docs) — SDK setup and the
  self-hosting guide.
- [GitHub OAuth apps](https://github.com/settings/developers) — where the two
  required credentials come from, unless you use another provider.
- [Quickwit](https://github.com/quickwit-oss/quickwit) — the search engine
  (Apache-2.0).

### Implementation Details

Five services build from this template's repository, each from its own
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
- **quickwit** — `quickwit/quickwit:v0.8.2`, listening on the private network
  only. The frontend creates the search indexes on boot from definitions
  vendored at the same tag as the Laminar image, because the published image
  does not include them and would otherwise leave search returning nothing.
- **postgres** — `postgres:16`, database and user baked, data in a subdirectory
  of the volume because a Railway volume root holds a root-owned `lost+found`
  that `initdb` refuses.

**Set the OAuth callback URL after deploying.** Create the OAuth app first with
any placeholder callback, deploy with its client ID and secret, then set the
callback to `https://YOUR-FRONTEND-DOMAIN/api/auth/callback/github`, using the
domain Railway gave the frontend service. This order matters: with no identity
provider configured, Laminar's self-hosted sign-in accepts any email address
with no password, so the template refuses to start rather than come up open.
The deploy form asks for GitHub, but Google, Microsoft Entra ID, Okta and
Keycloak all work; the README lists the variables for each.

What `LITE` gives up is throughput rather than features. Span processing runs
in-process instead of through a broker, and the web app runs as a single replica
because there is no Redis to hold a cross-replica lock. Ingestion rate limiting
and PII redaction are off for the same reason.

## Why Deploy Laminar on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway
will host your infrastructure so you don't have to deal with configuration,
while allowing you to vertically and horizontally scale it.

By deploying Laminar on Railway, you are one step closer to supporting a
complete full-stack application with minimal burden. Host your servers,
databases, AI agents, and more on Railway.
