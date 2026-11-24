#!/bin/sh -e
# Start script for Fidus Writer on Synology.
#
# The package ships a default configuration.py (via the bridge's `files`
# mechanism, mounted read-only under /etc/fiduswriter-synology). Copy it
# into the data folder on first start so that it stays editable there —
# both directly and through the DSM window (Manage -> Settings).

if ! [ -f /data/configuration.py ]; then
    echo "*** Installing the default Fidus Writer configuration ..."
    cp /etc/fiduswriter-synology/configuration.py /data/configuration.py
fi

# The bridge's settings editor writes this file as root with mode 600,
# which the app (running as its own non-root user) cannot read - the app
# would then silently fall back to the base settings. Make sure it stays
# readable on every start; the bridge restarts the app after each
# settings save, so this also heals files written through the DSM window.
chmod a+r /data/configuration.py 2>/dev/null || true

exec /bin/sh /etc/start-fiduswriter.sh
