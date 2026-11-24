# AGENTS.md — fiduswriter-synology

## Project overview

Fidus Writer on Synology DSM: SPK packaging (via
[moritzfl/synology-docker-bridge](https://github.com/moritzfl/synology-docker-bridge))
plus the `synology` Django app that authenticates Fidus Writer against the
bridge's DSM identity headers.

- License: `AGPL-3.0`
- Repository: `https://git.fiduswriter.org/fiduswriter/fiduswriter-synology`

## Layout

- `fiduswriter/synology/` — Django app (middleware + tests), pip package
  `fiduswriter-synology`. In development, symlink it into
  `fiduswriter-server-backend/fiduswriter/synology` and run
  `python manage.py test synology` from `fiduswriter-server-backend/fiduswriter/`
  (same pattern as the other plugin repos).
- `packaging/` — `app.json` for the bridge's SPK generator, the derived
  image `Dockerfile`, the default `configuration.py`, `start.sh`, icon.
  Validate changes with
  `node packaging/generate.mjs --config packaging/app.json --check`
  from a checkout of the bridge repository.

## Conventions

- All platform-dependent code stays in this repository — nothing
  Synology-specific goes into fiduswriter-server-backend.
- The middleware must keep requiring the `X-Bridge-Secret` match against
  the secret file before trusting identity headers.
