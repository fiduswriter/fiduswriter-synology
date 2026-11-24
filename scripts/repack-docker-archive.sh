#!/bin/sh
# Post-process an SPK built by synology-docker-bridge's generate.mjs so the
# embedded image.tar is in the classic docker-archive format DSM expects.
#
# Recent Docker versions with the containerd image store make
# `docker save` emit an OCI layout (blobs/sha256/, index.json), which
# DSM's docker-project worker cannot import ("Import failed:
# /var/packages/<id>/target/image.tar"). This script converts the tar to
# docker-archive with podman and repacks the SPK.
#
# Usage: scripts/repack-docker-archive.sh <spk-file> <image> [<image> ...]
#   <image> are the images embedded in the SPK, e.g.
#   fiduswriter-synology:spk fiduswriter-bridge:spk
# Requires: podman (rootless is fine).

set -e

SPK="$1"
shift
[ -n "$SPK" ] && [ "$#" -ge 1 ] || {
    echo "usage: $0 <spk-file> <image> [<image> ...]" >&2
    exit 2
}
command -v podman >/dev/null || { echo "podman is required" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

tar xf "$SPK" -C "$WORK"
mkdir "$WORK/payload"
tar xzf "$WORK/package.tgz" -C "$WORK/payload"

if ! tar tf "$WORK/payload/image.tar" | grep -q '^oci-layout$'; then
    echo "$SPK: already docker-archive, nothing to do"
    exit 0
fi

echo "$SPK: converting OCI image.tar to docker-archive ..."
podman load -i "$WORK/payload/image.tar" >/dev/null
podman save --format docker-archive -o "$WORK/payload/image.tar.new" "$@"
mv "$WORK/payload/image.tar.new" "$WORK/payload/image.tar"

tar czf "$WORK/package-new.tgz" -C "$WORK/payload" image.tar docker ui config files
mv "$WORK/package-new.tgz" "$WORK/package.tgz"

OUT="${SPK%.spk}-dockerarchive.spk"
tar cf "$OUT" -C "$WORK" INFO package.tgz PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG scripts conf
echo "wrote $OUT"
