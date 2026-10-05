# gitea-mirror

[gitea-mirror](https://github.com/RayLabsHQ/gitea-mirror) mirroring GitHub
repositories into a Gitea instance.

## Services

| Service | Image | Internal port | Domain |
| --- | --- | --- | --- |
| `gitea-mirror` | `ghcr.io/raylabshq/gitea-mirror:latest` | 4321 | `GITEA_MIRROR_URL` |

In Coolify, give `gitea-mirror` a domain on port 4321 matching
`GITEA_MIRROR_URL`. The image ships its own health check.

## Variables

| Variable | Feeds | Notes |
| --- | --- | --- |
| `BETTER_AUTH_SECRET` | gitea-mirror | Signs sessions and encrypts its login keys. Generate with `openssl rand -base64 32`. |
| `ENCRYPTION_SECRET` | gitea-mirror | Encrypts the stored GitHub and Gitea tokens. Generate with `openssl rand -base64 48`. |
| `GITEA_MIRROR_URL` | `BETTER_AUTH_URL`, `PUBLIC_BETTER_AUTH_URL`, `BETTER_AUTH_TRUSTED_ORIGINS` | Public URL of the mirror UI, no trailing slash. |
| `HTTP_IDLE_TIMEOUT` | `BUN_CONFIG_HTTP_IDLE_TIMEOUT` | Seconds an outgoing HTTP request may sit idle before Bun drops it. Set it to at least the target Gitea's clone timeout. Defaults to `3600`; at most `14340`. |

Behind a reverse proxy, gitea-mirror rejects sign-in with "invalid origin"
unless all three Better Auth variables hold the external URL, so one variable
feeds them all.

Both secrets are set explicitly rather than left to the image, which would
otherwise generate its own into `gitea-mirror-data`. Data encrypted under one
secret is unreadable under another, so moving the data to a new deployment
means carrying the secrets with it. Never change either on an existing
install.

## Choices

- **Waits as long as Gitea clones.** Gitea's migrate API sends nothing until
  the clone ends, and Bun's `fetch` drops a connection idle for 5 minutes.
  gitea-mirror then marks the repository failed while Gitea keeps cloning; on
  retry it finds the half-made repository and marks it mirrored. If that
  clone later fails, Gitea keeps an empty repository with no mirror record,
  which never syncs. `HTTP_IDLE_TIMEOUT` is set at least as long as Gitea's
  clone timeout so the request outlives the clone. Bun caps it at 239
  minutes, so a larger value stops helping there.
- **`gitea-mirror:latest`** with `pull_policy: always`: upstream publishes no
  major tag, so every redeploy takes the newest release.

## Usage

Sign up at `GITEA_MIRROR_URL`, then in its settings enter the Gitea instance's
public URL and an access token, plus the GitHub token to mirror from. These
are stored in `gitea-mirror-data`, not in the environment.

## Storage

| Volume | Holds |
| --- | --- |
| `gitea-mirror-data` | Mirror job database, settings and generated secrets |
