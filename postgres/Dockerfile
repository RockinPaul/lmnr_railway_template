# PostgreSQL for Laminar's configuration, users, projects and API keys.
#
# The database name and user are fixed for this template, so they are baked in
# rather than asked for at deploy time. PGDATA points at a subdirectory of the
# volume because a Railway volume root contains a root-owned `lost+found`, which
# `initdb` refuses to treat as an empty data directory.
FROM postgres:16

ENV POSTGRES_DB=lmnr \
    POSTGRES_USER=lmnr \
    PGDATA=/var/lib/postgresql/data/pgdata
