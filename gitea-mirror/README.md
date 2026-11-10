# gitea-mirror

[gitea-mirror](https://github.com/RayLabsHQ/gitea-mirror) mirroring GitHub
repositories into a Gitea instance.

## Services

| Service | Image | Internal port | Domain |
| --- | --- | --- | --- |
| `gitea-mirror` | `ghcr.io/raylabshq/gitea-mirror:latest` | 4321 | `GITEA_MIRROR_URL` |

In Coolify, give `gitea-mirror` a domain on port 4321 matching
`GITEA_MIRROR_URL`. The image ships its own health check; the compose file
keeps its command and only slows how often it runs.

## Variables

| Variable | Feeds | Notes |
| --- | --- | --- |
| `BETTER_AUTH_SECRET`, `ENCRYPTION_SECRET` | gitea-mirror | Sign sessions and encrypt the stored tokens. Leave empty to let the image generate them. |
| `GITEA_MIRROR_URL` | `BETTER_AUTH_URL`, `PUBLIC_BETTER_AUTH_URL`, `BETTER_AUTH_TRUSTED_ORIGINS` | Public URL of the mirror UI, no trailing slash. |
| `GITHUB_USERNAME`, `GITHUB_TOKEN` | gitea-mirror | Account to mirror from and its token, with the `repo` and `admin:org` scopes. |
| `GITEA_URL`, `GITEA_USERNAME`, `GITEA_TOKEN` | gitea-mirror | Gitea instance as this container reaches it, the account mirrors belong to, and its token. |
| `PRIVATE_REPOSITORIES`, `PUBLIC_REPOSITORIES` | gitea-mirror | Which of the account's repositories to import. Both default to `true`. |
| `MIRROR_STARRED`, `AUTO_MIRROR_STARRED` | gitea-mirror | Import starred repositories and mirror them on scheduled syncs. Both default to `true`. |
| `STARRED_REPOS_MODE` | gitea-mirror | Defaults to `preserve-owner`: a starred repository stays under its original owner's name. |
| `GITEA_ORG_VISIBILITY` | gitea-mirror | Visibility of the organizations it creates. Defaults to `private`. |
| `GITEA_CREATE_ORG`, `GITEA_ADD_TOPICS` | gitea-mirror | Create missing organizations and copy repository topics. Both default to `true`. |
| `SCHEDULE_ENABLED`, `SCHEDULE_INTERVAL`, `SCHEDULE_TIMEZONE`, `SCHEDULE_BATCH_SIZE` | gitea-mirror | Sync schedule. Defaults to on, hourly (`0 * * * *`), `Asia/Saigon`, 5 repositories at a time. |
| `AUTO_MIRROR_REPOS` | gitea-mirror | Mirror newly imported repositories on scheduled syncs. Defaults to `true`. |
| `CLEANUP_ENABLED`, `CLEANUP_DELETE_IF_NOT_IN_GITHUB` | gitea-mirror | Handle repositories gone from GitHub, by archiving them. Both default to `true`. |
| `PRE_SYNC_BACKUP_STRATEGY` | gitea-mirror | Backup before each sync: `disabled`, `always`, `on-force-push` or `block-on-force-push`. Defaults to `disabled`. |
| `HTTP_IDLE_TIMEOUT` | `BUN_CONFIG_HTTP_IDLE_TIMEOUT` | Seconds an outgoing HTTP request may sit idle before Bun drops it. Set it to at least the target Gitea's clone timeout. Defaults to `3600`; at most `14340`. |

Behind a reverse proxy, gitea-mirror rejects sign-in with "invalid origin"
unless all three Better Auth variables hold the external URL, so one variable
feeds them all.

When `BETTER_AUTH_SECRET` and `ENCRYPTION_SECRET` are empty, the image
generates them on first start into `gitea-mirror-data` and reuses them after,
so the secrets travel with the data they encrypt. An install that already
sets them must keep setting the same values: data encrypted under one secret
is unreadable under another.

## Choices

- **Settings live in the environment.** Whenever a connection variable is set,
  the entrypoint rewrites the stored settings from the environment on every
  boot, so a change made in the UI lasts only until the next restart unless the
  variable changes too. A boolean left unset counts as `false`, whatever
  upstream documents as its default, so `PUBLIC_REPOSITORIES`,
  `GITEA_CREATE_ORG`, `GITEA_ADD_TOPICS` and
  `CLEANUP_DELETE_IF_NOT_IN_GITHUB` are set explicitly.
- **Waits as long as Gitea clones.** Gitea's migrate API sends nothing until
  the clone ends, and Bun's `fetch` drops a connection idle for 5 minutes.
  gitea-mirror then marks the repository failed while Gitea keeps cloning; on
  retry it finds the half-made repository and marks it mirrored. If that
  clone later fails, Gitea keeps an empty repository with no mirror record,
  which never syncs. `HTTP_IDLE_TIMEOUT` is set at least as long as Gitea's
  clone timeout so the request outlives the clone. Bun caps it at 239
  minutes, so a larger value stops helping there.
- **Health check every 5 minutes.** Each call to `/api/health` also asks
  GitHub's API, without a token, for the latest gitea-mirror release, and a
  failed answer is not cached. At the image's 30-second interval that is 120
  calls an hour against GitHub's limit of 60 unauthenticated calls per IP, so
  the check fails and logs a 403 every time. Five minutes makes it 12. During
  the first 30 seconds it still checks every 5 seconds, so a deploy turns
  healthy as quickly as before. Mirroring itself uses the GitHub token and is
  unaffected either way.
- **`gitea-mirror:latest`** with `pull_policy: always`: upstream publishes no
  major tag, so every redeploy takes the newest release.

## Usage

Sign up at `GITEA_MIRROR_URL`; the settings load onto the first account. A
stored backup strategy wins over `PRE_SYNC_BACKUP_STRATEGY`, so changing the
variable later does not change an existing account; change it in the UI.

## Storage

| Volume | Holds |
| --- | --- |
| `gitea-mirror-data` | Mirror job database, settings and generated secrets |
