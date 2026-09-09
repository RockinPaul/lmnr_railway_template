# Laminar's Next.js web app: the trace UI, the auth flows, and the migrations.
#
# On boot this service applies the Postgres migrations, the ClickHouse
# migrations and the seed data, so it is the only service that needs write
# access to both stores and the only one whose first start is slow.
FROM ghcr.io/lmnr-ai/frontend:v0.2.4

# LITE selects self-hosted behaviour: it runs the migrations on boot and turns
# off the cloud-only billing and landing-page features. PORT is what Railway
# routes to. The ClickHouse username and database are fixed for this template.
# HOSTNAME=:: makes Node listen on the IPv6 wildcard, which on Linux is a
# dual-stack socket. The upstream image sets 0.0.0.0, and Railway does not
# consider a service started until it sees an IPv6 listener, so an IPv4-only
# bind leaves the deployment stuck in "deploying" forever.
ENV ENVIRONMENT=LITE \
    PORT=8080 \
    HOSTNAME=:: \
    CLICKHOUSE_USER=lmnr \
    CLICKHOUSE_RO_USER=lmnr \
    CLICKHOUSE_DB=default

COPY --chmod=755 entrypoint.sh /railway-entrypoint.sh
COPY --chmod=644 wait-for-deps.mjs /railway-wait-for-deps.mjs

ENTRYPOINT ["/railway-entrypoint.sh"]
