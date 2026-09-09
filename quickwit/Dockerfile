# Quickwit backs Laminar's full-text span search.
#
# Without it the search box silently returns no results: the lookup fails and
# the frontend swallows the error, so a user reads "no matches" rather than
# "search is off". That is why it is part of this template rather than an
# optional extra.
FROM quickwit/quickwit:v0.8.2

# Quickwit binds all three of its sockets to one host, and the image ships
# 0.0.0.0, which Railway's IPv6 private network cannot reach. The data
# directory moves into a subdirectory of the volume, because a Railway volume
# root holds a root-owned `lost+found`, and because mounting a volume over
# /quickwit would hide the packaged config.
ENV QW_LISTEN_ADDRESS=:: \
    QW_DATA_DIR=/qwdata/data

COPY --chmod=755 entrypoint.sh /railway-entrypoint.sh
ENTRYPOINT ["/railway-entrypoint.sh"]
