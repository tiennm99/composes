# composes

Personal docker compose collection. One directory per service, each holding
`compose.yml`, its own `README.md`, a committed `.env.example`, and a
gitignored `.env`.

## File naming

Every service uses `compose.yml` — the current Compose spec name, and the
shorter one. Not `docker-compose.yml`.

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

## Service READMEs stay inside their directory

A service's `README.md` describes that service and nothing else. It does not
name, link to, or compare itself with another service, and it does not link up
to the root README or CLAUDE.md. Shared conventions — the workspace volume
split, no published ports, the restart policy, secrets, variable order — are
written once at the root and are not restated or "see the root for why"-linked
from a service. A service README says what the service is, its variables,
storage and wiring, and the reasons behind choices specific to that service.
Keep it concise and minimal.

This is a deployment rule, not a style preference. Each service is a separate
Coolify app whose webhook watch path is `<service>/**`. A cross-link means
renaming or editing one service touches another's directory and redeploys it.
Cross-cutting changes to every compose file (a new restart policy, say) are the
one legitimate case where a push redeploys several services.

Every Coolify app created from this repo sets its watch path to `<service>/**`.
An app with no watch path deploys on every push to the repository —
`traffmonetizer` leaves it unset on purpose, to get restarted that often.

## Service directories hold deploy files only

Because of that watch path, every file in a service directory redeploys the
service when it changes. A service directory holds only what the deploy reads
or what describes it: `compose.yml`, `README.md`, `.env.example`,
`.gitignore`, and any `Dockerfile`, entrypoint or config file the build or
containers use.

- **Agent skills** for a service — maintenance scripts, runbooks — go in the
  root `.claude/skills/<name>/`, never in `<service>/.claude/`. A skill there
  also only loads once a session touches that directory.
- **Docs** beyond the README go in the root `docs/<service>/`, named exactly
  like the service directory; renaming a service renames its docs directory in
  the same commit. The service `README.md` covers only what the service is and
  how to deploy it — variables, storage, wiring, and the reasons behind its
  configuration. Anything issue-related — known problems, log noise,
  troubleshooting, investigations, upstream research and audits — goes in
  `docs/<service>/`. The README does not link there; docs may link to the
  service.
- **Anything else** that is not deploy input — CI workflows, test fixtures —
  has no default home. Ask the user where it goes before adding it to a
  service directory.

## Workspace services

A service someone works *inside* — an editor, a coding agent, anything with a
shell — gets exactly two named volumes: one for the container user's home
directory, one mounted at `/workspace`. The home volume holds settings,
credentials and CLI logins; `/workspace` holds the code. Point whatever
variable selects the working directory at `/workspace`.

`code-server`, `paseo` and `opencode` all follow this. A service with no
human inside it does not — one that spawns a container per session keeps only
its own state volume.

The split is so that wiping one does not take the other. Reinstalling an editor
should not cost you a repository, and deleting a repository should not cost you
your extensions and logins.

Check who owns `/workspace` on a fresh volume. Docker creates it `root:root`
unless the image ships the directory, and an image that drops to a non-root
user will not be able to write there. `code-server` needs an explicit `chown`
for this reason; `paseo` and `opencode` do not.

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
`# - KEY=${KEY:-default}`, so the service runs without them and enabling one
means uncommenting its line. The matching `.env.example` entry is commented out
the same way (`# KEY=default`). Must-have and should-have variables stay active.

Do not write the tier into the file as a comment — the order is the
documentation. Where every variable is required, as in `alloy`, the tiers
collapse and the existing grouping stands.

`.env.example` follows its compose file's order. The names differ — one
`PASSWORD` can feed several container variables, and `SERVICE_HOSTNAME` feeds
`HOST` — so each entry sits where the first compose entry that reads it sits.
Reordering a compose file means reordering the `.env.example` with it.

## Deployment target

Services are deployed through Coolify, not plain `docker compose` on a host.
The platform owns the parts a standalone compose file would declare itself.

Coolify is the primary target: design, test and debug against it first.
Dokploy is optional — keep a service working there when it costs nothing
(the `restart:` policy below), but never trade Coolify behaviour for Dokploy
compatibility, and do not block on Dokploy-only issues.

## Intentional omissions — do not "fix" these

These are deliberate, not oversights. Do not flag them as defects or add them
unprompted:

- **No `ports:`.** Coolify and Dokploy attach the container to their proxy
  network and map a domain to the internal port. Publishing a port is redundant
  and would additionally expose it on the host.
- **No `container_name:`.** Let Compose derive it from the directory.

More generally: these files are tuned to one person's setup and are not meant
to be portable, standard, or turnkey. Prefer leaving a service minimal over
adding hardening or convention that the platform already provides.

`restart:` is the exception that is *not* omitted. Every service sets
`restart: unless-stopped`, on every container. Coolify injects that exact value
when a service does not declare one, and keeps the declared value when it does;
Dokploy does not inject anything, so in its default compose mode an omitted
policy leaves the container down after a crash or a host reboot. Setting it is
correct on both.

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

## Upstream sources

`sources/` is for upstream source checkouts used while debugging, cloned as
`sources/<owner>/<repo>` at the version the service runs. Its contents are
gitignored; only `sources/.gitkeep` is tracked. Never commit a checkout or fix
a service by editing code there. Use the `debug-service` skill
(`.claude/skills/debug-service/SKILL.md`) for service issues.
