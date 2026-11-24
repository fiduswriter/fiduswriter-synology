# Fidus Writer on Synology

This repository packages [Fidus Writer](https://fiduswriter.org) as a
[Synology DSM](https://www.synology.com/dsm) package (SPK), and holds the
small Django app that ties Fidus Writer's authentication to Synology's. It
is part of the Fidus Writer 5.0 family of host integrations, alongside the
Nextcloud and WordPress versions.

Fidus Writer is an online collaborative editor made for academics who need
citations and/or formulas. It focuses on content rather than layout, so the
same text can later be published in multiple formats: website, printed book
or ebook. On Synology it runs the **full server** — including real-time
collaboration through the Rust-based Aethonan websocket route — not the
file-based DAV variant.

## Thanks

This integration builds on
[moritzfl's synology-docker-bridge](https://github.com/moritzfl/synology-docker-bridge)
and on his prototype of Fidus Writer on Synology
([fiduswriter/fiduswriter#1427](https://github.com/fiduswriter/fiduswriter/issues/1427)).
Thank you, Moritz, for both the generic bridge and for exploring the
Fidus Writer integration — the packaging here follows your approach
closely.

## What the package gives you

- **A first-party DSM app**: Fidus Writer opens in a normal DSM desktop
  window and at `https://<nas>:<dsm-port>/fiduswriter/` (Login Portal) and
  its own web ports (defaults 8098/8099), on DSM's own certificate — no
  extra firewall rule or certificate exception.
- **SSO with DSM accounts, and direct access**: users signed in to DSM are
  signed in to Fidus Writer automatically (names, email addresses and the
  `administrators` group come from the DSM account). At the same time the
  app can be used **without a DSM login** — Fidus Writer's own login and
  registration pages work for local accounts, exactly like any standalone
  Fidus Writer installation. See "Authentication model" below.
- **Access control through DSM**: who may open the app is governed by DSM
  **Application Privileges**. Revoking the privilege ends the user's
  sessions, and removal from the DSM administrators group revokes admin
  rights on the next request.
- **Settings in the DSM window**: administrators edit
  `configuration.py` (the standard Fidus Writer configuration) under
  **Manage → Settings**; a failed configuration is rolled back
  automatically.

## Authentication model

The bridge proxies the app and, for requests with a DSM session, adds the
identity headers `Remote-User`, `Remote-Name`, `Remote-Email` and
`Remote-Groups` plus a random `X-Bridge-Secret` that it keeps in the app
data folder as `/data/.bridge-secret`. The `synology` Django app in this
repository (`fiduswriter/synology/`) provides a middleware that:

- only trusts the identity headers when `X-Bridge-Secret` matches the
  secret file (so no other process on the NAS can pose as a user),
- logs the corresponding user in, creating the account on first use with
  the DSM email address and full name, and mapping membership of the DSM
  `administrators` group to Django staff/superuser (re-checked on every
  request),
- ends the sessions it created when the identity headers disappear (the
  user signed out of DSM or lost the app privilege), while leaving
  username/password sessions untouched.

Every Fidus Writer URL is registered as a bridge *public path*, so
requests **without** a DSM session still reach the app — Fidus Writer's own
access checks apply, so document share links keep working for people
without DSM accounts. The app's `csrftoken` and `sessionid` cookies are
allowed on those paths, so local-account login sessions work too.

Known gap: the bridge currently does not accept `/` itself as a public
path, so a *session-less* visitor opening the bare root of the web port is
sent through DSM sign-in first; every real page URL (login, documents,
shares, …) works directly. Allowing a public root is a small upstream
change we have asked the bridge for.

## Repository layout

| Path | Purpose |
| --- | --- |
| `fiduswriter/synology/` | Django app: `SynologyBridgeAuthMiddleware`, tests. Pip-installable (`pip install fiduswriter-synology`); in development, symlink it into `fiduswriter-server-backend/fiduswriter/synology`. |
| `packaging/app.json` | App config for the bridge's SPK generator. |
| `packaging/Dockerfile` | Derived image: official Fidus Writer image + this package. |
| `packaging/configuration.py` | Default `configuration.py` installed on first start (enables the middleware). |
| `packaging/start.sh` | Installs the default config into `/data`, then runs the image's own start script. |
| `packaging/icon.svg` | Package icon (the Fidus Writer logo). |

## Building the SPK

Requirements: Node.js 22+, Docker with buildx, `rsvg-convert`
(`apt install librsvg2-bin` / `brew install librsvg`).

```bash
git clone https://github.com/moritzfl/synology-docker-bridge.git
cd synology-docker-bridge
git checkout <pinned ref>
(cd bridge && npm ci)

# Validate the app config without building:
node packaging/generate.mjs \
    --config /path/to/fiduswriter-synology/packaging/app.json --check

# Build the SPK (builds the derived image and embeds it):
node packaging/generate.mjs \
    --config /path/to/fiduswriter-synology/packaging/app.json
```

The result is `packaging/dist/fiduswriter-<version>-x86_64.spk` (pass
`--arch armv8` for ARM models — the Fidus Writer image is built for both
x86_64 and aarch64). Install through **Package Center → Manual Install**.

## Which user the app runs as

`app.json` sets `"appUser": "0:0"`: the app container runs as root, which is
what the bridge generates by default and what most DSM packages do. This is
a deliberate choice after the field test on a DS1019+ showed the
alternatives broken:

- The Fidus Writer image's own user is uid 999. Docker resolves the
  `user: "fiduswriter"` line against the image's passwd, so the container
  runs as uid 999 — **not** the DSM package user (`fiduswriter`, a
  high uid such as 213894 assigned by DSM at install). DSM grants the
  package's data share to that DSM user, so the app cannot read or write
  `/data` at all (DisallowedHost on the real hostname, then
  "Container stopped unexpectedly" on the next restart when an
  unreadable `configuration.py` exists).
- `appUser: "package"` would run the container as the DSM package user
  with the share granted on install — the intended bridge design — but
  the Fidus Writer image keeps all writable state (database, media,
  `static-transpile`, `.transpile`) in the image directory owned by uid
  999, so it cannot run as an arbitrary uid without image changes
  (making `PROJECT_PATH` point at `/data`).

Running as root inside the container lets the app use the share
regardless of DSM's ACLs. The container is still only reachable through
the bridge (which itself runs as root with the Docker socket, like all
bridge packages). A hardening pass could make the image uid-agnostic and
switch to `appUser: "package"`.

## Known gaps and upstream issues

- **Public root path**: the bridge does not accept `/` itself as a public
  path, so a *session-less* visitor opening the bare root of the web port
  is sent through DSM sign-in first; every real page URL (login,
  documents, shares, …) works directly. Allowing a public root is a small
  upstream change we have asked the bridge for.
- **Config file permissions**
  ([bridge#8](https://github.com/moritzfl/synology-docker-bridge/issues/8)):
  the bridge's settings editor writes `configuration.py` root-owned with
  mode 600. With the app running as root (see above) this no longer
  breaks the app; it still surprises File Station users. `start.sh`
  re-creates the file when it is missing.
- **Image tar format**
  ([bridge#9](https://github.com/moritzfl/synology-docker-bridge/issues/9)):
  on Docker hosts with the containerd image store, `docker save` emits an
  OCI layout that DSM's package importer rejects ("Import failed:
  /var/packages/fiduswriter/target/image.tar"). Run
  `scripts/repack-docker-archive.sh <spk> fiduswriter-synology:spk
  fiduswriter-bridge:spk` after `generate.mjs` to convert the embedded
  tar to the classic docker-archive format (needs podman).
- **NAS-side networking**: the web ports are served by DSM's nginx on the
  NAS's own addresses. Browsers on the LAN must be able to resolve the
  DSM host name to the NAS (NAT hairpinning or a local DNS override) for
  the DSM desktop window to embed the app, and the NAS certificate must
  be trusted on the app port the first time. Everything also works
  directly via the web ports (e.g. `https://<nas-ip>:8099/`).
- **Admin pages in the image**: the Fidus Writer image runs its startup
  transpile with the working directory at `/fiduswriter`, so the
  staff-only admin bundles that import `../../base/assets/...` fail to
  resolve there (the main editor bundles compile fine). Cosmetic for the
  Synology use case; a fix belongs in the image (run with the project
  path where the apps live).

## Installing on a NAS

1. Install **Container Manager** from Package Center (the SPK declares it
   as a dependency).
2. Manual-install the SPK.
3. Open the Fidus Writer desktop icon. The first start performs the
   Fidus Writer database setup; subsequent starts take a few seconds.
4. (Optional) Change the web ports or edit settings via **Manage →
   Settings** in the window.

## Configuration reference

The middleware is activated by these settings in `configuration.py`
(the shipped default enables them):

| Setting | Default | Meaning |
| --- | --- | --- |
| `SYNOLOGY_BRIDGE_AUTH` | `False` | Trust the bridge identity headers and log users in. |
| `SYNOLOGY_BRIDGE_SECRET_PATH` | `/data/.bridge-secret` | Where the bridge keeps the shared secret. |
| `SYNOLOGY_BRIDGE_AUTO_CREATE_USERS` | `True` | Create Fidus Writer accounts for DSM users on first use. When `False`, only users that already exist can sign in. |

Regular Fidus Writer settings (database, email, registration, …) work as
on any installation; see `configuration-default.py` in
fiduswriter-server-backend and the
[Fidus Writer documentation](https://fiduswriter.github.io/).

## Development

The middleware's unit tests live in `fiduswriter/synology/tests.py` and
run through the main application's test runner (per the pattern used by
all Fidus Writer plugins):

```bash
cd fiduswriter-server-backend/fiduswriter
ln -s ../../fiduswriter-synology/fiduswriter/synology synology
python manage.py test synology
rm synology
```

## License

AGPL-3.0, matching Fidus Writer.
