# Vendored Quickwit index definitions

These three files come from `frontend/lib/quickwit/indexes/` in
[lmnr-ai/lmnr](https://github.com/lmnr-ai/lmnr) at tag **v0.2.4**, the same tag
as the `ghcr.io/lmnr-ai/frontend` image this template pins (Apache-2.0).

They are vendored because the published frontend image does not include them:
its Dockerfile copies `lib/db/migrations` and `lib/clickhouse/migrations` into
the standalone output but not `lib/quickwit/indexes`. Upstream's own startup
code reads that directory to create the search indexes, and without it logs
"Quickwit indexes directory not found, skipping index initialization", leaving
the search box returning no results forever.

**When bumping the image tag, re-fetch these files at the new tag.** If a future
image ships them itself, drop this directory and the `COPY` in the Dockerfile.
