# code-server-base

[VS Code in the browser](https://github.com/linuxserver/docker-code-server),
from the LinuxServer image, stock.

The starting point for a new code-server instance: the image as it ships, with
no mods and no extra packages. Only a password, a timezone, and a workspace
path are set. Copy the directory and add `DOCKER_MODS` / `INSTALL_PACKAGES` to
build a kitted-out box — [code-server](../code-server/README.md) is that same
image with Go, Node.js, Python, and a pile of CLI tools layered on.

Both use a volume named `code-server-config`, but Compose namespaces volumes by
project and the project is named after the directory, so the two instances stay
independent.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASSWORD` | Web UI login, also the in-container sudo password. **A blank value disables authentication entirely.** |

Generate a password with `openssl rand -base64 24`.

`PUID`/`PGID` are pinned to `1000` and `TZ` to `Asia/Ho_Chi_Minh` in the
compose file — the first user on my hosts, and my timezone. Change them in
place if neither holds.

The upstream example also offers `HASHED_PASSWORD`, `SUDO_PASSWORD_HASH`, and
`PROXY_DOMAIN`. The hash variants are left out because the plaintext ones
already come from a gitignored `.env`, and `PROXY_DOMAIN` because Coolify and
Dokploy terminate the domain at their own proxy.

## Networking

Listens on `8443`. No ports are published — point the domain at that port in
Coolify or Dokploy. See the [root README](../README.md) for why.

## Storage

Everything lives in the `code-server-config` named volume mounted at `/config`;
the default workspace is `/config/workspace`. Removing the volume wipes your
files, settings, and extensions.
