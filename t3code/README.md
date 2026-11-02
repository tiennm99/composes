# t3code

[T3 Code](https://github.com/pingdotgg/t3code) server, which runs coding agents
and is controlled from its web, desktop and mobile apps. Upstream ships no
Docker image, so a local `Dockerfile` builds one from `ubuntu:24.04`, and
`entrypoint.sh` runs upstream's installer into `$HOME` on first start.

## Setup

1. Point the domain at port `3773` and deploy.
2. Open a shell in the container and create a link for your device:

   ```sh
   t3 auth pairing create --base-url https://t3code.example.com --ttl 10m
   ```

3. Open the printed `Pair URL` in a browser, or paste it into **Add environment**
   in the desktop or mobile app. Use a fresh link for each device.
4. Install and log in to the agent CLIs you want from that shell, for example:

   ```sh
   curl -fsSL https://claude.ai/install.sh | bash
   claude auth login
   ```

   Restart the app so the server detects a new CLI.
5. Set **Settings → Threads → New threads → Permissions**. New threads default
   to **Full access**.

Add repositories under `/workspace`.

## Environment

| Variable | Purpose |
| --- | --- |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity for agents and terminals. |
| `SERVICE_HOSTNAME` | Container hostname, shown as the machine name in the apps and the prompt. |
| `T3CODE_TELEMETRY_ENABLED` | Set to `false` to stop product usage events and relay traces. Enabled by default. |

`HOST` is set to `SERVICE_HOSTNAME` because Coolify injects `HOST=0.0.0.0`,
which zsh would otherwise show as the prompt's host name. T3 Code does not read
it.

## Exposure

The domain is the only way in, and a pairing token is the only login on it. Treat
a `Pair URL` as a password while it is unused.

`--host 0.0.0.0` is set because the server otherwise stays on loopback in a
container, out of the proxy's reach. The server builds its public URLs from
`Host` and `X-Forwarded-Proto`, which the proxy passes through.

Every start logs a pairing token and URL, so treat the deploy log as secret too.
The logged URL uses the container's private address, which is why setup creates a
link with `--base-url`. `t3 pair` has no such flag and prints the same private
address.

T3 Connect is not set up. Its documented setup, `t3 up`, runs a systemd user
service, which the container lacks.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `t3code-home` | `/home/ubuntu` | The `t3` CLI and its downloaded versions, T3 Code's state and paired devices, agent CLIs and their logins |
| `t3code-workspace` | `/workspace` | Repositories the agents work on |

## Image

- The CLI lives at `~/.local/bin/t3`, a symlink into `~/.t3/runtime/versions` on
  the home volume, so an update survives a redeploy. To update, run `t3 update`
  in a shell, then restart the app. The running server keeps the old version
  until it restarts.
- `init: true` reaps the agent and terminal processes the server leaves behind,
  since the server would otherwise be PID 1.
- The `ubuntu` user has passwordless `sudo`. Anyone who pairs already has a shell
  as that user.
