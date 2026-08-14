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
  README.md       # what it is, its variables, how it's wired
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

Each links to its own README for variables, ports, and storage.

| Service | What it is |
| --- | --- |
| [code-server](code-server/README.md) | VS Code in the browser, as a remote dev box |
