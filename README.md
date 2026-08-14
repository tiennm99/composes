# composes

My docker compose collection — one directory per service, each self-contained.

These are tuned to my own setup, not written as general-purpose templates. They
are deployed through [Coolify](https://coolify.io) and
[Dokploy](https://dokploy.com), so they lean on the platform for things a
standalone compose file would normally declare:

- **No published ports.** Both platforms attach the container to their proxy
  network and map a domain directly to the internal port, so `ports:` is
  unnecessary — and adding it would expose the host port as well.
- **No `restart:` policy.** The platform manages the container lifecycle.

Treat them as working examples rather than drop-in configs. Running one with
plain `docker compose` means adding whatever your setup needs.

## Layout

```
<service>/
  compose.yml     # the service definition
  .env.example    # required variables, committed
  .env            # real values, gitignored
```

Compose names the project after its directory, so `code-server/` comes up as
the `code-server` project with its own network and volumes.

## Usage

In Coolify or Dokploy, point a Docker Compose resource at the service directory
and set the environment variables from its `.env.example`.

Locally, for a quick check:

```sh
cd <service>
cp .env.example .env    # then fill it in
docker compose up -d
docker compose logs -f
docker compose down
```

`.env` is picked up automatically because it sits next to `compose.yml`.
Never commit it — the root `.gitignore` covers `.env`/`*.env` and re-includes
`.env.example`.

## Services

### code-server

[VS Code in the browser](https://github.com/linuxserver/docker-code-server),
from the LinuxServer image, set up as a full remote dev box.

Comes with Go, Node.js 24, Python 3, pnpm, and zsh via LinuxServer mods, plus
`gh`, `git`, `ffmpeg`, `imagemagick`, and other CLI tools through
`INSTALL_PACKAGES`. Git author/committer identity is injected from `.env`.

Everything lives in the `code-server-config` named volume mounted at `/config`;
the default workspace is `/config/workspace`. Removing the volume wipes your
files, settings, and extensions.

| Variable | Purpose |
| --- | --- |
| `PASSWORD` | Web UI login, also the in-container sudo password. **A blank value disables authentication entirely.** |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity |
| `CODEX_ACCESS_TOKEN` | OpenAI Codex CLI auth; leave blank if unused |

Generate a password with `openssl rand -base64 24`.

Listens on `8443` — point the domain at that port in Coolify or Dokploy.
