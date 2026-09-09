# ClickHouse for Laminar's span and trace storage.
#
# Upstream ships two configuration files that its compose file bind-mounts.
# Railway has no bind mounts, so they are baked into the image here, with one
# Railway-specific addition: ClickHouse must listen on IPv6 to be reachable
# over Railway's private network.
FROM clickhouse/clickhouse-server:26.5

# The username is fixed for this template and is baked in on every service that
# needs it, so it never becomes a deploy-time question. The password arrives as
# CLICKHOUSE_PASSWORD from the template's generated secret.
ENV CLICKHOUSE_USER=lmnr \
    CLICKHOUSE_DB=default

COPY config.d-railway.xml /etc/clickhouse-server/config.d/railway.xml
COPY users.d-lmnr.xml /etc/clickhouse-server/users.d/lmnr.xml
