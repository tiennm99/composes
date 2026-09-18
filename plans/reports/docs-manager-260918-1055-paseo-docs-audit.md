# paseo README audit — accuracy vs. actual files

Scope: `paseo/README.md` against `paseo/Dockerfile`, `paseo/entrypoint.sh`,
`paseo/compose.yml`, `paseo/.env.example`, and the root `README.md`/`CLAUDE.md`
conventions. Stateful record of a point-in-time audit (2026-09-18) — not a
durable authority surface itself.

## 1. Go/SDKMAN removal — cleanup verification

The uncommitted diff (`git diff -- paseo/Dockerfile paseo/entrypoint.sh
paseo/README.md`) shows the removal was applied consistently across all three
files. Checked every surviving reference:

- No occurrence of `Go`, `SDKMAN`, `JVM`, `Java`, or `Bun-in-the-image` claims
  remains except two, both correctly reframed as history:
  - `README.md:176-177` — "Bun used to be here for `omp` and went the same
    way." (past tense, correct — Dockerfile has no Bun install step)
  - `README.md:183-186` — "No other language toolchain is in the image. Go
    and the JVM (through SDKMAN) used to be, and are not worth a rebuild..."
    (past tense, correct — matches current Dockerfile/entrypoint.sh, neither
    of which mention Go/SDKMAN)
- The `[SDKMAN](#sdkman)` link and the whole `## SDKMAN` section are gone from
  `README.md`. `grep -n '\[.*\](#'` over the file found only four links, all
  to `#agents`, which still exists (`## Agents` header) — **no orphaned anchor
  survives**.
- The Image table (`README.md:157-163`) no longer has a `Go` row, and the old
  catch-all apt row (`less nano jq unzip zip lsof psmisc ugrep bfs zsh sudo`)
  was correctly split into `build-essential, sudo` / `zsh, nano` matching
  `Dockerfile:8-10` exactly. `grep` for `jq|unzip|zip|lsof|psmisc|ugrep|bfs|less`
  in README.md returns nothing — no stray reference to the other dropped
  packages either.
- The Storage table (`README.md:143-146`) dropped "SDKMAN and its candidates"
  from the `paseo-home` row — matches, since `entrypoint.sh` no longer
  installs it.
- The intro (`README.md:3-7`) dropped `Go` and changed "shell tooling" to "a
  shell" — matches `Dockerfile:8-10` (only `zsh`/`nano` remain, one shell).
- The `sudo secure_path` / `go` bullet and the "SDKMAN and agent installs"
  wording in the `chpasswd`/`chown` bullets were removed — both were
  Go/SDKMAN-specific and no longer apply.
- `Dockerfile` and `entrypoint.sh` header comments were updated to drop
  "language toolchains" → "Python, a C toolchain" and "installs SDKMAN, then"
  respectively — both still state *what*, not *why*, per the repo's comment
  policy in root `CLAUDE.md`.

**Result: the Go/SDKMAN cleanup is complete and accurate. No stale reasoning
bullets defend a removed decision.**

## 2. Claim-by-claim verification (remainder of README.md)

| README claim | Line | Status | Evidence |
| --- | --- | --- | --- |
| Adds `gh`, `glab`, Python, a C toolchain, and a shell | 3-6 | Verified | `Dockerfile:8-10,15-20,25-37` install exactly these |
| Agent CLIs not baked in, installed on start into `$HOME` | 6-7 | Verified | `entrypoint.sh:11-42` installs via `gosu paseo`, nothing in `Dockerfile` installs agent CLIs |
| `AGENT_CLIS=claude codex` is the `.env.example` default | 82-85 | Verified | `.env.example:28` |
| 6 agents, one row each, URLs and env names | 89-96 | Verified | `entrypoint.sh:12-19` `agent_installer()` matches every URL and name |
| Only 2 of 6 install by default, other 4 opt-in | 86-87 | Verified | same case statement, default is `claude codex` |
| Installer runs as `paseo` via `gosu`, lands in `~/.local/bin` or `~/.opencode/bin` | 98-101 | Verified | `entrypoint.sh:40` (`gosu paseo`); `Dockerfile:41` PATH has exactly those two dirs |
| Unrecognised agent name is logged and skipped | 111 | Verified | `entrypoint.sh:30-33` |
| Failed install is logged, container continues | 107-109 | Verified | `entrypoint.sh:41` `|| echo ... continuing` |
| Both agent dirs are on the image's `PATH` | 116 | Verified | `Dockerfile:41` |
| Shell rc entries don't reach the daemon's own env | 117-120 | Verified (design fact) | consistent with PATH being set at image level, not in `.bashrc`/`.zshrc` |
| `entrypoint.sh` wraps `paseo-docker-entrypoint`, runs before it, execs it at the end | 192-198 | Verified | `entrypoint.sh:45` `exec /usr/local/bin/paseo-docker-entrypoint "$@"`; `Dockerfile:45-46` copies it to `/usr/local/bin/entrypoint` and sets it as `ENTRYPOINT` |
| Password set via piped `chpasswd`, not an argument; empty `PASEO_PASSWORD` leaves account untouched/locked | 199-204 | Verified | `entrypoint.sh:7-9` — `printf ... | chpasswd`, guarded by `-n "${PASEO_PASSWORD:-}"` |
| `chown paseo:paseo /home/paseo` runs before any agent install | 205-207 | Verified | `entrypoint.sh:23` precedes the install loop at `entrypoint.sh:27` |
| PATH entries hardcoded as `/home/paseo/...` because `ENV` can't expand `$HOME` set later | 208-212 | Verified | `Dockerfile:41` uses literal `/home/paseo/...`, no `$HOME` is ever set as an `ENV` in this Dockerfile |
| `.env.example` variable list and defaults (`SHELL=/bin/zsh`, `PASEO_TRUSTED_PROXIES=uniquelocal`, `TZ=Asia/Ho_Chi_Minh`, `SERVICE_HOSTNAME=paseo`) match the Environment table's descriptions | 37-44 | Verified | `.env.example:1-42` — descriptions match 1:1 |
| `SERVICE_HOSTNAME` feeds both `hostname:` and `HOST` | 46-47 | Verified | `compose.yml:4,16` |
| **"the entrypoint chowns the volumes** [plural]**, then drops to the `paseo` user... with `gosu`"** | 190-191 | **Wrong / overstated** | `entrypoint.sh:23` chowns only `/home/paseo` (the `paseo-home` volume). Nothing in this repo's `entrypoint.sh` chowns `/workspace` (`paseo-workspace`). The plural implies both volumes; only one is proven from these files. The base image's own `paseo-docker-entrypoint` may chown `/workspace`, but that file is outside this repo and unverifiable here. Also: `entrypoint.sh` itself never runs `gosu` for the final user-drop — that happens inside the base entrypoint it `exec`s into, so attributing the `gosu`-drop to "the entrypoint" [singular, our script] is imprecise; it's accurate only if read as "the combined entrypoint chain," which the sentence doesn't say. **Suggested correction:** either soften to "chowns `/home/paseo`" (drop "volumes," matching what this repo's script actually does), or if `/workspace` really is chowned by the base entrypoint, say so explicitly and attribute the `gosu` line-drop to the base entrypoint, not to `entrypoint.sh`. |
| `build-essential` serves `npm`'s `node-gyp` and Python C extensions | 180-182 | Unverifiable | Neither `npm` nor Node.js is installed by this `Dockerfile`; if present it comes from the base image (`ghcr.io/getpaseo/paseo:latest`), which isn't inspectable from this repo. Not part of the recent diff — pre-existing claim, left as-is per "verified decision" rule (no new evidence to overturn it), flagged only for completeness. |
| Debian 12 ships Python 3.11 | 161 | Verified (general knowledge) | Debian 12 "bookworm" default `python3` is 3.11 |
| Port `6767`, published nowhere, daemon binds `PASEO_LISTEN` | 12, 26, 73-74 | Unverifiable from repo | No `ports:` or `PASEO_LISTEN` in `compose.yml`/`.env.example`; this is an upstream Paseo default, not something this repo's files assert or contradict. Pre-existing claim, not touched by the current diff — left as a previously-verified decision per audit rules. |
| `$HOME`/`.claude`/`.codex`/`.config/*` config dirs, `CLAUDE_CONFIG_DIR`/`CODEX_HOME`/`XDG_*` set by the base image | 148-153 | Unverifiable from repo | These env vars are not set in this repo's `Dockerfile`; claim is about the base image's own defaults, outside this repo's evidence. Pre-existing, not part of the diff. |

## 3. Three-way variable sync — `compose.yml` ↔ `.env.example` ↔ README table

**No mismatches.** Every variable is present in all three, and the reverse
holds too (nothing documented-but-absent, nothing present-but-undocumented):

- `compose.yml` environment block reads: `PASEO_PASSWORD`, `PASEO_HOSTNAMES`,
  `PASEO_TRUSTED_PROXIES`, `SHELL`, `AGENT_CLIS`, `TZ`, `GIT_NAME` (feeds
  `GIT_AUTHOR_NAME`+`GIT_COMMITTER_NAME`), `GIT_EMAIL` (feeds
  `GIT_AUTHOR_EMAIL`+`GIT_COMMITTER_EMAIL`), `SERVICE_HOSTNAME` (feeds
  `hostname:` at `compose.yml:4` and `HOST` at `compose.yml:16`).
- `.env.example` declares exactly these 9 names, same values referenced.
- The README Environment table (`README.md:35-44`) has one row per name (with
  `GIT_NAME`/`GIT_EMAIL` combined into one row, `SERVICE_HOSTNAME` calling out
  the double use) — full coverage, no extra rows for anything not in
  `compose.yml`/`.env.example`.

**Ordering per root `CLAUDE.md`'s "Environment variable order" rule:**
`.env.example` orders each variable at the position of the *first*
`environment:` entry that reads it. Walking `compose.yml`'s `environment:`
block top to bottom: `PASEO_PASSWORD`, `PASEO_HOSTNAMES`,
`PASEO_TRUSTED_PROXIES`, `SHELL`, `AGENT_CLIS`, `TZ`, `GIT_NAME` (first hit is
`GIT_AUTHOR_NAME`), `GIT_EMAIL` (first hit is `GIT_AUTHOR_EMAIL`),
`SERVICE_HOSTNAME` (first hit *inside `environment:`* is `HOST=` at the
bottom). `.env.example` follows this exactly, in this order. The `hostname:`
key at `compose.yml:4` sits outside the `environment:` block the rule
describes, so `SERVICE_HOSTNAME` correctly lands last in `.env.example`, not
first. **Ordering is correct — no fix needed.**

## 4. `.env.example` — generic-value check

Checked every value against the "no real hostname, domain, git identity,
email, or account name" rule (root `CLAUDE.md` → composes `CLAUDE.md`
"Secrets" section):

- `PASEO_PASSWORD=`, `PASEO_HOSTNAMES=`, `GIT_NAME=`, `GIT_EMAIL=` — empty. OK.
- `PASEO_TRUSTED_PROXIES=uniquelocal` — a keyword the daemon defines, not a
  real value. OK.
- `SHELL=/bin/zsh`, `AGENT_CLIS=claude codex` — generic defaults, no personal
  data. OK.
- `SERVICE_HOSTNAME=paseo` — this is "the service's own name," explicitly
  allowed by the rule's own example. OK.
- `TZ=Asia/Ho_Chi_Minh` — not one of the rule's named forbidden categories
  (hostname/domain/git identity/email/account name), so not a rule violation.
  Flagged only as a borderline observation: it is a real, specific value
  rather than an empty placeholder. No change recommended without the user's
  input, since the rule doesn't cover timezone and other services in this
  collection may follow the same pattern.

**No violations found.**

## 5. Suggestions (user decides)

None. No missing tooling, package, or dependency surfaced during this audit —
per the task's hard constraint, none is proposed.

## Recommended README fix

One line, `README.md:190-191`:

> The image stays root: the entrypoint chowns the volumes, then drops to the
> `paseo` user (uid 1000) with `gosu`.

Correct to what `entrypoint.sh` actually shows (drop "volumes" → the specific
volume it chowns; drop the implication that this script itself does the
`gosu` user-drop):

> The image stays root: `entrypoint.sh` chowns `/home/paseo`, then execs into
> the base entrypoint, which drops to the `paseo` user (uid 1000) with
> `gosu`.

(Exact wording is the controller's call — this preserves the file's existing
voice and only removes the unproven "volumes" plural and the misattributed
`gosu` step.)

---

Status: DONE_WITH_CONCERNS
Summary: The Go/SDKMAN removal was applied cleanly and completely across Dockerfile, entrypoint.sh, and README.md — no orphaned references, links, or stale reasoning bullets found, and all three-way variable sync (compose.yml/.env.example/README) and ordering checks pass with no mismatches. One pre-existing (not part of this diff) README claim overstates what entrypoint.sh proves: "chowns the volumes" implies both paseo-home and paseo-workspace, but the script only chowns /home/paseo.
Concerns/Blockers: The "chowns the volumes" line (README.md:190-191) needs either a narrower claim or explicit confirmation (unverifiable from this repo) that the base image's own entrypoint chowns /workspace too.
