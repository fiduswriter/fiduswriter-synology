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
# podman prefixes the names with "localhost/"; DSM's compose expects the
# bare names (fiduswriter-synology:spk, ...). podman's own tag/untag
# juggling around duplicate names is unreliable, so save under the
# localhost names (in argument order, one manifest entry per image) and
# patch the archive's manifest RepoTags back to the bare names below.
save_names=""
for image in "$@"; do
    if podman image exists "localhost/$image" 2>/dev/null; then
        save_names="$save_names localhost/$image"
    elif podman image exists "$image" 2>/dev/null; then
        save_names="$save_names $image"
    else
        echo "cannot find loaded image $image" >&2
        exit 1
    fi
done
# shellcheck disable=SC2086
podman save --multi-image-archive --format docker-archive \
    -o "$WORK/payload/image.tar.new" $save_names
mv "$WORK/payload/image.tar.new" "$WORK/payload/image.tar"

WORK="$WORK" MANIFEST_IMAGES="$*" python3 - <<'EOF'
import io
import json
import os
import tarfile
import tempfile

work = os.environ["WORK"]
names = os.environ["MANIFEST_IMAGES"].split()
src = os.path.join(work, "payload", "image.tar")

with tarfile.open(src, "r:") as fh:
    manifest = json.load(fh.extractfile("manifest.json"))
assert len(manifest) == len(names), (len(manifest), len(names))
for entry, name in zip(manifest, names):
    entry["RepoTags"] = [name]
patched = json.dumps(manifest).encode("utf-8")

fd, tmp = tempfile.mkstemp(dir=os.path.join(work, "payload"), suffix=".tar")
os.close(fd)
try:
    with tarfile.open(src, "r:") as old, tarfile.open(
        tmp, "w", format=tarfile.GNU_FORMAT
    ) as new:
        for member in old:
            if member.name == "manifest.json":
                continue
            new.addfile(
                member, old.extractfile(member) if member.isfile() else None
            )
        info = tarfile.TarInfo("manifest.json")
        info.size = len(patched)
        new.addfile(info, io.BytesIO(patched))
    os.replace(tmp, src)
except BaseException:
    os.unlink(tmp)
    raise
EOF

tar czf "$WORK/package-new.tgz" -C "$WORK/payload" image.tar docker ui config files
mv "$WORK/package-new.tgz" "$WORK/package.tgz"

OUT="${SPK%.spk}-dockerarchive.spk"
tar cf "$OUT" -C "$WORK" INFO package.tgz PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG scripts conf
echo "wrote $OUT"
