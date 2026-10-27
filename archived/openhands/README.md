# openhands

[OpenHands](https://openhands.dev) — a coding agent with a web UI. The app
container is only the front half: every agent session runs in a separate
*agent-server* container that this one creates on the host through the Docker
socket. Nothing is built here; the upstream image is complete.

## Setup

1. Point the domain at port `3000` and deploy. There is nothing to fill in —
   the service has no environment file.
2. Open the domain and set the LLM provider and API key in the UI. They are
   written to the state volume and survive a redeploy.

## Docker socket

Mounted read-write, and it has to be: the app creates and destroys containers,
and connecting to a Unix socket needs write permission on it. The `:ro` mount
that [code-server](../code-server/README.md) uses would fail here.

That is full control of the host daemon, which is root-equivalent — the agent
can start a container that mounts anything. It is the price of the Docker
runtime; the alternative is running OpenHands somewhere it does not share a
daemon with anything else.

`host.docker.internal` is required for the same architecture. Agent-server
containers are siblings started by the host daemon, not members of this compose
project's network, and they publish their port on the host. The app reaches
them by that name, so without the `extra_hosts` entry the UI loads and every
session then fails to connect.

## Workspace

There is none on the host. `SANDBOX_VOLUMES` is deliberately unset, so the
agent sees only the storage inside its own sandbox container and cannot touch
a host path. Clone into the sandbox from the agent's terminal instead.

Setting it would mean a *host* path — the sibling container's mounts are
resolved by the host daemon, so a named volume or a path inside the app
container is not a valid value.

## Environment

Nothing is per-deployment, so there is no `.env.example`. What
`compose.yml` sets:

| Variable | Purpose |
| --- | --- |
| `AGENT_SERVER_IMAGE_REPOSITORY` | Where to pull the sandbox image from |
| `AGENT_SERVER_IMAGE_TAG` | Which sandbox image to run. `-python` is the Python/Node toolchain variant; `-golang`, `-java` and others exist |
| `TZ` | Timestamps in the UI and logs |
| `LOG_ALL_EVENTS` | Full agent event stream in the container logs, which is what makes a failed session diagnosable |

The app image tracks `latest` while the agent-server tag is pinned, which looks
inconsistent and is not. GHCR publishes no floating tag for
`openhands/agent-server` at all — its tags are version-and-toolchain triples
like `1.26.0-python` — so there is nothing to track. Bump it by hand when the
app image moves far enough that the two disagree; the app pulls it on first
session, so a wrong tag shows up as a session that never starts, not as a
failed deploy.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `openhands-state` | `/.openhands` | Settings, LLM credentials, conversation history |

`/.openhands` is at the filesystem root, not under `$HOME` — the upstream
`docker run` mounts the host's `~/.openhands` there, and only the container
side matters to a named volume.

Sandbox containers keep their own storage and are not covered by this volume.

## Networking

Listens on `3000`, published nowhere — the platform maps the domain to it. See
the [root README](../README.md) for why.

Sandbox containers do publish on the host, on ports the app picks, because that
is how the app reaches them. They are not reachable through the domain; serving
a preview running inside a sandbox would need `AGENT_SERVER_USE_HOST_NETWORK`
and `SANDBOX_CONTAINER_URL_PATTERN`, which this setup does not configure.

## Related

- [opencode-web](../opencode-web/README.md) — a coding agent that runs in its own container instead of spawning one
- [paseo](../paseo/README.md) — runs agent CLIs, including OpenHands' competitors, in a terminal
