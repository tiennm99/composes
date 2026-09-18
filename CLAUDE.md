# composes

Personal docker compose collection. One directory per service, each holding
`compose.yml`, its own `README.md`, a committed `.env.example`, and a
gitignored `.env`.

## File naming

New services use `compose.yml` — the current Compose spec name, and the
shorter one. Existing services that still use `docker-compose.yml` stay as
they are; do not rename them, not even while touching the file for something
else.

## Installing software in an image

Follow the upstream project's own documented install method, or the one the
community has settled on. In order of preference: the vendor's signed package
repository, the vendor's official tarball or install script, then a well-known
community installer. Do not hand-roll a download, and do not take a stale
distro package just because `apt install` is shorter — check what version it
actually gives you first.

## Comments in compose files, Dockerfiles and scripts

This holds for every file in a service directory, not just the compose file.

A comment says *what* a section installs, configures or does, in a line or
two. It does not explain *why*. Reasons — why not the distro package, why that
directory, why a version is pinned, why a step runs here and not there, what
would break if it were simplified — go in the service's `README.md`, where
they can be read in full and where someone deciding whether to change
something will actually look.

So: no rationale, no trade-offs, no cautionary notes in the file itself. When a
choice needs defending, write the defence in the README and let the header
comment point at it. Keep the README current whenever a file changes, otherwise
the reasoning is simply lost rather than relocated.

The root `README.md` is an index only — it covers the shared conventions and
links out to each service. Per-service detail (variables, ports, storage)
belongs in that service's README, not the root one. Adding a service means
adding its README and a row to the root table.

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

Do not write the tier into the file as a comment — the order is the
documentation. Where every variable is required, as in `alloy`, the tiers
collapse and the existing grouping stands.

`.env.example` follows its compose file's order. The names differ — one
`PASSWORD` can feed several container variables, and `SERVICE_HOSTNAME` feeds
`HOST` — so each entry sits where the first compose entry that reads it sits.
Reordering a compose file means reordering the `.env.example` with it.

## Deployment target

Services are deployed through Coolify and Dokploy, not plain `docker compose`
on a host. The platform owns the parts a standalone compose file would declare
itself.

## Intentional omissions — do not "fix" these

These are deliberate, not oversights. Do not flag them as defects or add them
unprompted:

- **No `ports:`.** Coolify and Dokploy attach the container to their proxy
  network and map a domain to the internal port. Publishing a port is redundant
  and would additionally expose it on the host.
- **No `restart:` policy.** The platform manages the container lifecycle.
- **No `container_name:`.** Let Compose derive it from the directory.

More generally: these files are tuned to one person's setup and are not meant
to be portable, standard, or turnkey. Prefer leaving a service minimal over
adding hardening or convention that the platform already provides.

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
`SERVICE_HOSTNAME` in `code-server` and `paseo`.
