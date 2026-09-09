# Laminar's Next.js web app: the trace UI, the auth flows, and the migrations.
#
# On boot this service applies the Postgres migrations, the ClickHouse
# migrations and the seed data, so it is the only service that needs write
# access to both stores and the only one whose first start is slow.
FROM ghcr.io/lmnr-ai/frontend:v0.2.4

# LITE selects self-hosted behaviour: it runs the migrations on boot and turns
# off the cloud-only billing and landing-page features. PORT is what Railway
# routes to. The ClickHouse username and database are fixed for this template.
# The IPv6 bind is set in the entrypoint, not here: Railway injects HOSTNAME at
# run time and it would override an ENV set in the image.
ENV ENVIRONMENT=LITE \
    PORT=8080 \
    CLICKHOUSE_USER=lmnr \
    CLICKHOUSE_RO_USER=lmnr \
    CLICKHOUSE_DB=default

# The published image copies lib/db/migrations and lib/clickhouse/migrations
# into its standalone output but not lib/quickwit/indexes, so upstream's own
# startup code cannot create the search indexes and logs "Quickwit indexes
# directory not found". These are the same files at the same tag as the image.
# See quickwit-indexes/README.md; re-fetch them when bumping the image.
COPY --chown=1001:1001 quickwit-indexes/*.yaml /app/lib/quickwit/indexes/

COPY --chmod=755 entrypoint.sh /railway-entrypoint.sh
COPY --chmod=644 wait-for-deps.mjs /railway-wait-for-deps.mjs

ENTRYPOINT ["/railway-entrypoint.sh"]
