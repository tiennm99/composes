# composes

Personal docker compose collection. One directory per service, each holding
`compose.yml`, its own `README.md`, a committed `.env.example`, and a
gitignored `.env`.

Topic rules live in `.claude/rules/` and load with this file:

- `naming.md` — file, directory, service, volume and network names, with
  example role names for supporting containers.
- `images-and-comments.md` — where and how software is installed, and what
  comments in compose files, Dockerfiles and scripts may say.
- `workspace-services.md` — the home and `/workspace` volume split for services
  someone works inside.
- `environment-and-secrets.md` — `environment:` order, `.env.example`, and
  secrets.

## Deployment target

Services are deployed through Coolify, not plain `docker compose` on a host.
The platform owns the parts a standalone compose file would declare itself.

Coolify is the primary target: design, test and debug against it first.
Dokploy is optional — keep a service working there when it costs nothing
(the `restart:` policy below), but never trade Coolify behaviour for Dokploy
compatibility, and do not block on Dokploy-only issues.

## Service READMEs stay inside their directory

This rule has high priority: editing one service must never redeploy another.
A service's `README.md` describes that service and nothing else. It does not
name, link to, or compare itself with another service, and it does not link up
to the root README, CLAUDE.md or `.claude/rules/`. Shared conventions — the workspace volume
split, no published ports, the restart policy, secrets, variable order — are
written once at the root and are not restated or "see the root for why"-linked
from a service. A service README says what the service is, its variables,
storage and wiring, and the reasons behind choices specific to that service.
Keep it concise and minimal.

The root `README.md` is an index only — it covers the shared conventions and
links out to each service. Per-service detail (variables, ports, storage)
belongs in that service's README, not the root one. Adding a service means
adding its README and a row to the root table.

This is a deployment rule, not a style preference. Each service is a separate
Coolify app whose webhook watch path is `<service>/**`. A cross-link means
renaming or editing one service touches another's directory and redeploys it.
Cross-cutting changes to every compose file (a new restart policy, say) are the
one legitimate case where a push redeploys several services.

Every Coolify app created from this repo sets its watch path to `<service>/**`.
After creating one, check `watch_paths` with the Coolify MCP `get_application`;
`null` means the app deploys on every push to the repository. Only these are
`null` and expected — do not flag or "fix" them:

- `traffmonetizer`, on both `miti-sg` and `miti-jp`, leaves it unset on purpose
  to be restarted on every push.

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

## Intentional omissions — do not "fix" these

These are deliberate, not oversights. Do not flag them as defects or add them
unprompted:

- **No `ports:`.** Coolify and Dokploy attach the container to their proxy
  network and map a domain to the internal port. Publishing a port is redundant
  and would additionally expose it on the host. Coolify's `ports_exposes`
  field (often a prefilled `3000`) is never read for compose apps; the proxy
  port comes from the compose `expose:` entry or the domain's port. Leave it.
- **No `container_name:`.** Let Compose derive it from the directory.

More generally: these files are tuned to one person's setup and are not meant
to be portable, standard, or turnkey. Prefer leaving a service minimal over
adding hardening or convention that the platform already provides.

`restart:` is the exception that is *not* omitted. Every service sets
`restart: unless-stopped`, on every container. Coolify injects that exact value
when a service does not declare one, and keeps the declared value when it does;
Dokploy does not inject anything, so in its default compose mode an omitted
policy leaves the container down after a crash or a host reboot. Setting it is
correct on both. `traffmonetizer` sets `restart: always` on purpose, to be
restarted as often as possible.

## Upstream sources

`sources/` is for upstream source checkouts used while debugging, cloned as
`sources/<owner>/<repo>` at the version the service runs. Its contents are
gitignored; only `sources/.gitkeep` is tracked. Never commit a checkout or fix
a service by editing code there. Use the `debug-service` skill
(`.claude/skills/debug-service/SKILL.md`) for service issues.
