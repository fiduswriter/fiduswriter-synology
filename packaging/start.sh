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

exec /bin/sh /etc/start-fiduswriter.sh
