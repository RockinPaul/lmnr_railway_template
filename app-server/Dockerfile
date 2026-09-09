# Laminar's Rust API server: OTLP ingest, the query API and the realtime stream.
#
# Two things are added on top of the upstream image. socat, because the server
# binds 0.0.0.0 (IPv4) on all three of its ports while Railway's private network
# is IPv6, so sibling services cannot reach it without a bridge. And the fixed
# self-hosted settings, so they are never deploy-time questions.
FROM ghcr.io/lmnr-ai/app-server:v0.2.4

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends socat \
    && rm -rf /var/lib/apt/lists/*

# LITE drops the runtime dependency on RabbitMQ; spans are processed in-process.
# PORT is what Railway routes to and what the public OTLP endpoint listens on.
# The ClickHouse username is fixed for this template and baked on every service
# that needs it, so it never nulls into a deploy-time field.
ENV ENVIRONMENT=LITE \
    PORT=8080 \
    GRPC_PORT=8001 \
    CONSUMER_PORT=8002 \
    CLICKHOUSE_USER=lmnr \
    CLICKHOUSE_RO_USER=lmnr \
    IPV6_HTTP_PORT=8100 \
    IPV6_REALTIME_PORT=8102

COPY --chmod=755 entrypoint.sh /railway-entrypoint.sh
ENTRYPOINT ["/railway-entrypoint.sh"]
