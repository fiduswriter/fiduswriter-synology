# Fidus Writer on Synology

This repository packages [Fidus Writer](https://fiduswriter.org) as a
[Synology DSM](https://www.synology.com/dsm) package (SPK) using
[moritzfl's synology-docker-bridge](https://github.com/moritzfl/synology-docker-bridge).
It is part of the Fidus Writer 5.0 family of host integrations, alongside the
Nextcloud and WordPress versions.

Fidus Writer is an online collaborative editor made for academics who need
citations and/or formulas. It focuses on content rather than layout, so the
same text can later be published in multiple formats: website, printed book
or ebook.

## What the package gives you

- **A first-party DSM app**: Fidus Writer opens in a normal DSM desktop
  window and in the browser at `https://<nas>:<dsm-port>/fiduswriter/` (via
  DSM Login Portal), on DSM's own ports and certificate — no extra port,
  firewall rule or certificate exception.
- **SSO with DSM accounts**: users signed in to DSM are signed in to
  Fidus Writer automatically. User names, email addresses and full names
  come from the DSM account; members of the DSM `administrators` group
  become Fidus Writer administrators. No second sign-in, no user
  provisioning.
- **Access control through DSM**: who may open the app is governed by DSM
  **Application Privileges** (every user by default; administrators can
  restrict it). Revoking the privilege ends the user's Fidus Writer
  sessions, and removal from the DSM administrators group revokes admin
  rights on the next request.
- **Settings in the DSM window**: administrators edit
  `configuration.py` (the standard Fidus Writer configuration) under
  **Manage → Settings**; a failed configuration is rolled back
  automatically.
- **Share links for outsiders**: document share links keep working for
  people without a DSM account (they are anonymous in Fidus Writer, as
  they would be on any Fidus Writer server).

## Architecture

```
DSM desktop window / Login Portal (DSM nginx, DSM certificate)
  └─ bridge proxy (synology-docker-bridge)
       ├─ adds identity headers for the signed-in DSM user:
       │    Remote-User, Remote-Name, Remote-Email, Remote-Groups
       │    + X-Bridge-Secret (random shared secret)
       └─► fiduswriter container (official image, port 8000)
                └─ synology.middleware.SynologyBridgeAuthMiddleware
                     verifies X-Bridge-Secret against /data/.bridge-secret
                     and logs the user in (auto-creating the account)
```

The Fidus Writer side is the bundled-but-optional `synology` Django app in
[fiduswriter-server-backend](https://git.fiduswriter.org/fiduswriter/fiduswriter-server-backend)
(`fiduswriter/synology/`). It only trusts the identity headers when the
request carries the shared secret that the bridge keeps in the app data
folder as `/data/.bridge-secret` (readable only by the app's user), so no
other process on the NAS can pose as a user by sending the headers itself.

## Building the SPK

Requirements: Node.js 22+, Docker with buildx, `rsvg-convert`
(`apt install librsvg2-bin` / `brew install librsvg`).

```bash
git clone https://github.com/moritzfl/synology-docker-bridge.git
cd synology-docker-bridge
git checkout <pinned ref>
(cd bridge && npm ci)

# Validate the app config without building:
node packaging/generate.mjs --config /path/to/fiduswriter-synology/packaging/app.json --check

# Build the SPK (pulls the image in app.json and embeds it):
node packaging/generate.mjs --config /path/to/fiduswriter-synology/packaging/app.json
```

The result is `packaging/dist/fiduswriter-<version>-x86_64.spk` (add
`--arch armv8` for ARM models). Install it through **Package Center →
Manual Install**.

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
on any installation; see
`configuration-default.py` in fiduswriter-server-backend and the
[Fidus Writer documentation](https://fiduswriter.github.io/).

## Development

The middleware's unit tests live in fiduswriter-server-backend
(`fiduswriter/synology/tests.py`) and run with:

```bash
cd fiduswriter-server-backend/fiduswriter
python manage.py test synology
```

## License

AGPL-3.0, matching Fidus Writer.
