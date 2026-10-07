# Environment and secrets

## Environment variable order

`environment:` entries are ordered by how badly the service needs them — not
alphabetically, and not by when they were added:

1. **Must have** — without it the service does not do its job, or is exposed.
   Auth secrets, the uid/gid its files belong to, host allow-lists, proxy
   trust, and the mod list that supplies the toolchain.
2. **Should have** — it starts without these, but behaves wrongly for this
   setup: timezone, default workspace, shell, git identity, pinned tool
   versions, extra packages.
3. **Optional** — cosmetics and conveniences; dropping one changes nothing
   functional. Window titles, prompt labels.

Grouping wins over the tiers. Variables that belong together stay on adjacent
lines — `PUID`/`PGID`, `PASSWORD`/`SUDO_PASSWORD`, the four `GIT_*` entries,
the `PASEO_*` daemon settings, `DOCKER_MODS` with the `INSTALL_PACKAGES` and
`NODEJS_MOD_VERSION` that configure it — and the whole group sits at the tier
of its most important member, even when a member on its own would rank lower.
Within a group, the variable others configure comes first.

Optional variables are listed but commented out, in the form
`# - KEY=${KEY:-default}` (`# KEY: ${KEY:-default}` in a map-style
`environment:`), so the service runs without them and enabling one
means uncommenting its line. The matching `.env.example` entry is commented out
the same way (`# KEY=default`). Must-have and should-have variables stay active.

Do not write the tier into the file as a comment — the order is the
documentation. Where every variable is required, as in `alloy`, the tiers
collapse and the existing grouping stands.

`.env.example` follows its compose file's order. The names differ — one
`PASSWORD` can feed several container variables, and `SERVICE_HOSTNAME` feeds
`hostname:` and `HOST` — so each entry sits where the first compose entry that reads it sits.
Reordering a compose file means reordering the `.env.example` with it.

## Secrets

Every service reads secrets from a sibling `.env`. Never commit one — the root
`.gitignore` covers `.env`/`*.env` and re-includes `.env.example`. Keep
`.env.example` in sync whenever a compose file gains or drops a variable.

`.env.example` is a template for anyone, so every value in it stays generic —
the service's own name, a placeholder domain, or an empty string. Never a real
hostname, git identity, email, domain or account name. Personal values are set
per deployment, in the Coolify or Dokploy environment for that app, and live
only in the gitignored `.env`.

Compose interpolation reads the deploying shell's environment before the
`.env` file, so a variable must not share a name with anything the shell
already exports. `HOSTNAME` is the trap: it is set inside every container,
including the one Coolify itself runs in, and would silently win. Hence
`SERVICE_HOSTNAME` in `code-server`, `code-server-lsio` and `paseo`.

A value stored in the Coolify app's environment, including its preview copy,
beats the `${VAR:-default}` default in `compose.yml`. Changing a default in the
repo does nothing while that stored value exists; clear it in Coolify, then
redeploy.
