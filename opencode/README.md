# opencode

[opencode](https://opencode.ai) served as a browser UI by `opencode web`, which
starts the headless server and its web interface together. The agent runs in
*this* container — there is no sandbox layer between it and the filesystem.

Built from a local `Dockerfile`, because the official image is the `opencode`
binary on bare Alpine and nothing else: no shell, no `git`, no `curl`, no
`ssh`. An agent whose main tool is "run a command" has nothing to run, so one
apk layer puts them back.

## Setup

Logging in to a model provider is the one step the UI cannot do. After the
first deploy, from a shell:

```sh
docker compose exec opencode opencode auth login
```

It is interactive, which is why it is not an environment variable; `exec`
gives it the TTY it needs. The credentials land on the `opencode-home` volume
and survive a redeploy.

Then open the domain and sign in with `OPENCODE_SERVER_USERNAME` and
`OPENCODE_SERVER_PASSWORD`.

The container logs a Bun stack trace ending in
`Executable not found in $PATH: "xdg-open"` on every start. `opencode web`
tries to open the UI in a local browser; there isn't one. It is noise — the
server is already listening by then, and the container keeps running.
Installing `xdg-utils` would silence it at the cost of pulling X11 in and
tripling the image, which is not worth it for a log line.

## Authentication

`OPENCODE_SERVER_PASSWORD` is the only thing between the domain and a shell on
this container. opencode's own words: *"If `OPENCODE_SERVER_PASSWORD` is not
set, the server will be unsecured."* Unset, every request is served — and every
request can ask the agent to run a command. Treat a blank value as publishing a
root terminal.

## Environment

| Variable | Purpose |
| --- | --- |
| `OPENCODE_SERVER_PASSWORD` | Web UI and API login. Blank means no authentication at all. Generate with `openssl rand -base64 24`. |
| `OPENCODE_SERVER_USERNAME` | Username to go with it. opencode falls back to `opencode`. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity for the agent's commits. |

Model provider credentials are not variables — see [Setup](#setup).

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `opencode-home` | `/root` | Provider credentials, config, session database, caches |
| `opencode-workspace` | `/workspace` | Code the agent works on |

The whole home directory is one volume because opencode spreads its state over
four places under it — `.config/opencode`, `.local/share/opencode` (the SQLite
session database), `.local/state/opencode` and `.cache/opencode` — and mounting
them separately would only be three more chances to miss one. Dotfiles and
anything else installed into `$HOME` persist as a side effect.

The container runs as root, which is what the upstream image does; `$HOME` is
`/root` because of it.

`WORKDIR /workspace` in the `Dockerfile` is what makes the agent start in the
workspace volume.

## Networking

Listens on `4096`; point the domain at it.

`--hostname 0.0.0.0` in `command:` is what makes the service reachable at all;
both `web` and `serve` bind `127.0.0.1` by default. `--port 4096` is there
because the default is `0`, a random port, which the platform cannot map a
domain to.

If the UI is loaded from a different origin than it is served from, add
`--cors <url>` to `command:`. The default setup does not need it.

## Image

`FROM ghcr.io/anomalyco/opencode:latest`, the vendor image. The opencode repo
moved out of the `sst` organisation; `ghcr.io/sst/opencode` still exists but no
longer serves anonymous pulls, so it is not the one to use.

The apk layer adds `bash`, `git`, `curl` and `openssh-client` — the floor for
an agent that clones, commits and fetches. It carries no language toolchain:
none is wanted often enough to justify rebuilding the image for everybody, and
`apk add` from the agent's own terminal covers a one-off — but `/usr` is not on
a volume, so it is gone on the next deploy. Something needed every time belongs
in the `Dockerfile`.

`ENTRYPOINT` stays the image's own `opencode`, so `command:` in `compose.yml`
is just the subcommand and its flags.
