# gitlab

Self-hosted [GitLab](https://about.gitlab.com/) Community Edition from the
official all-in-one image, which runs PostgreSQL, Redis, Sidekiq and nginx in one
container. Follows GitLab's
[Docker Compose guide](https://docs.gitlab.com/install/docker/installation/).

## Services

| Service | Image | Internal port | Domain |
| --- | --- | --- | --- |
| `gitlab` | `gitlab/gitlab-ce:latest` | 80 | `GITLAB_EXTERNAL_URL` |

In Coolify, give `gitlab` a domain on port 80 matching `GITLAB_EXTERNAL_URL`.

## Variables

| Variable | Feeds | Notes |
| --- | --- | --- |
| `GITLAB_EXTERNAL_URL` | `external_url` | Public URL, with `https://`. GitLab builds clone URLs and redirects from it. |
| `TZ` | Container, `gitlab_rails['time_zone']` | Defaults to `UTC`. |
| `GITLAB_SMTP_ENABLE` | `smtp_enable` | Defaults to `false`. Without SMTP, GitLab sends no working mail. |
| `GITLAB_SMTP_ADDRESS`, `GITLAB_SMTP_PORT` | `smtp_address`, `smtp_port` | Port defaults to `587`. |
| `GITLAB_SMTP_USER_NAME`, `GITLAB_SMTP_PASSWORD` | `smtp_user_name`, `smtp_password` | The password can hold any character. |
| `GITLAB_SMTP_DOMAIN` | `smtp_domain` | HELO domain. |
| `GITLAB_SMTP_STARTTLS_AUTO`, `GITLAB_SMTP_TLS` | `smtp_enable_starttls_auto`, `smtp_tls` | Default to `true` and `false`, which suits port 587. For implicit TLS on port 465, swap both. |
| `GITLAB_EMAIL_FROM`, `GITLAB_EMAIL_REPLY_TO` | `gitlab_email_from`, `gitlab_email_reply_to` | Set both when SMTP is on. |

Except for `GITLAB_SMTP_PASSWORD`, values are pasted into Ruby strings, so they
must not contain a single quote. The SMTP password stays a separate variable and
is read through `ENV`, so quotes and `#{}` in it cannot break the config.

## Choices

- **Bundled database.** The guide runs the bundled PostgreSQL, and GitLab
  upgrades it along with the image. Its data is in `gitlab-data`.
- **HTTPS only.** The proxy routes HTTP, not SSH, so the guide's SSH port is not
  published.
- **TLS ends at the proxy.** With an `https://` external URL, GitLab would
  otherwise serve 443 and request its own Let's Encrypt certificate, so nginx
  listens on plain port 80 and Let's Encrypt is off. GitLab still tells Rails
  the request was HTTPS.
- **Sign-up off.** GitLab has no `gitlab.rb` key for this, so
  `GITLAB_POST_RECONFIGURE_SCRIPT` sets it on every start, after migrations.
  Turning sign-up on in the UI lasts only until the next start.
- **Generated root password.** As in the guide, GitLab creates the password on
  first boot, so none sits in the app's environment.
- **`gitlab/gitlab-ce:latest`.** Upstream publishes no major tag, only exact
  versions and `latest`, and its guide recommends an exact version in
  production. Upgrades are triggered by hand, as described under **Upgrades**.
- **`shm_size: 256m`.** The default 64 MB is too small for GitLab's metrics
  files.

## Usage

The first boot takes a few minutes, and the container can report healthy before
nginx is up: the image's health check passes until its configuration is
rendered. Expect at least 5 GB of RAM in use.

Then read the password from the container and sign in as `root`:

```sh
grep 'Password:' /etc/gitlab/initial_root_password
```

The file is deleted on the first restart after 24 hours, so change the password
right away. Then, under **Admin > Settings > General > Visibility and access
controls**, set **Enabled Git access protocols** to **Only HTTP(S)**, so the UI
stops offering SSH clone URLs.

Admins create users under **Admin > Users**.

## Upgrades

A host reboot or container restart reuses the image already on the server, so it
does not change the version. A Coolify **Restart** or **Redeploy** pulls `latest`,
and so does a deploy from a push that changes this directory. On its first run,
the new image reconfigures GitLab and runs its database migrations. It can also
upgrade the bundled PostgreSQL.

Nothing is backed up automatically, and there is no automatic rollback. Before a
redeploy, in the container:

1. Check that background migrations have finished:
   `gitlab-rake gitlab:background_migrations:status`
2. Create a backup: `gitlab-backup create`. It is written to `gitlab-data`.
3. Copy `/etc/gitlab/gitlab-secrets.json` off the server. The backup does not
   include it, and a restore needs it.

GitLab must not skip a
[required upgrade stop](https://docs.gitlab.com/update/upgrade_paths/). They come
at x.2, x.5, x.8 and x.11, and `latest` does not step through them. If a redeploy
would cross one, first deploy that stop's exact tag, such as `19.8.x-ce.0` with
its real patch number, and let its background migrations finish before going back
to `latest`.

## Storage

| Volume | Holds |
| --- | --- |
| `gitlab-config` | `/etc/gitlab`: `gitlab.rb`, generated secrets and SSH host keys |
| `gitlab-logs` | `/var/log/gitlab` |
| `gitlab-data` | `/var/opt/gitlab`: repositories, uploads, PostgreSQL and Redis data |
