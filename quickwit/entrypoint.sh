#!/bin/sh
# Create the data directory on the volume, then start Quickwit.
#
# Quickwit will not create QW_DATA_DIR itself, and on a fresh Railway volume the
# mount point contains nothing but a root-owned `lost+found`.
set -eu

mkdir -p "${QW_DATA_DIR:-/qwdata/data}"
echo "quickwit data directory: ${QW_DATA_DIR:-/qwdata/data}, listening on ${QW_LISTEN_ADDRESS:-::}"

exec quickwit run
