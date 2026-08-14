# code-server

[VS Code in the browser](https://github.com/linuxserver/docker-code-server),
from the LinuxServer image, set up as a full remote dev box.

Comes with Go, Node.js 24, Python 3, pnpm, and zsh via LinuxServer mods, plus
`gh`, `git`, `ffmpeg`, `imagemagick`, and other CLI tools through
`INSTALL_PACKAGES`. Git author/committer identity is injected from `.env`.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASSWORD` | Web UI login, also the in-container sudo password. **A blank value disables authentication entirely.** |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity |

Generate a password with `openssl rand -base64 24`.

## Networking

Listens on `8443`. No ports are published — point the domain at that port in
Coolify or Dokploy. See the [root README](../README.md) for why.

## Storage

Everything lives in the `code-server-config` named volume mounted at `/config`;
the default workspace is `/config/workspace`. Removing the volume wipes your
files, settings, and extensions.
