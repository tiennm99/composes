# t3code

[T3 Code](https://github.com/pingdotgg/t3code) server, which runs coding agents
and is controlled from its web, desktop and mobile apps. Upstream ships no
Docker image, so a local `Dockerfile` builds one from `ubuntu:24.04`, and
`entrypoint.sh` runs upstream's installer into `$HOME` on first start.

T3 Code is reachable only on a Tailscale tailnet. A `tunnel` sidecar joins the
tailnet as its own machine and serves T3 Code over HTTPS at its MagicDNS name;
the service has no public domain. See [Exposure](#exposure).

## Setup

1. In the Tailscale admin console, enable MagicDNS and HTTPS certificates under
   **DNS**, and generate an auth key under **Settings → Keys**: not ephemeral,
   not reusable. Set it as `TS_AUTHKEY`. Give the app no domain, then deploy.
2. Under **Machines**, open the new `t3code` machine and choose **Disable key
   expiry**.
3. Open a shell in the `t3code` container and create a link for your device,
   using the tailnet name shown under **DNS**:

   ```sh
   t3 auth pairing create --base-url https://t3code.tailnet-name.ts.net --ttl 10m
   ```

4. On a device in the same tailnet, open the printed `Pair URL` in a browser, or
   paste it into **Add environment** in the desktop or mobile app. Use a fresh
   link for each device.
5. Install and log in to the agent CLIs you want from that shell, for example:

   ```sh
   curl -fsSL https://claude.ai/install.sh | bash
   claude auth login
   ```

   Restart the app so the server detects a new CLI.
6. Set **Settings → Threads → New threads → Permissions**. New threads default
   to **Full access**.

Add repositories under `/workspace`.

## Environment

| Variable | Purpose |
| --- | --- |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity for agents and terminals. |
| `SERVICE_HOSTNAME` | Container hostname, shown as the machine name in the apps and the prompt. |
| `T3CODE_TELEMETRY_ENABLED` | Set to `false` to stop product usage events and relay traces. Enabled by default. |
| `TS_AUTHKEY` | Tailscale auth key, used only for the node's first login. Required. |
| `TS_HOSTNAME` | Machine name on the tailnet, the first label of the MagicDNS name. Defaults to `t3code`. |

`HOST` is set to `SERVICE_HOSTNAME` because Coolify injects `HOST=0.0.0.0`,
which zsh would otherwise show as the prompt's host name. T3 Code does not read
it.

## Exposure

Pairing gives whoever holds the link a shell in the container, so the port is
reached only through Tailscale. The `tunnel` container runs `tailscaled` in
userspace mode, with no extra capabilities or `/dev/net/tun`, and `tailscale
serve` terminates HTTPS with a Let's Encrypt certificate for the MagicDNS name
and proxies to `t3code:3773` on the app's own network. Nothing is published on
the host or Coolify's proxy.

`--host 0.0.0.0` is set because the server otherwise stays on loopback in its
container, out of the `tunnel` container's reach. The server builds its URLs from
`Host` and `X-Forwarded-Proto`, which `tailscale serve` passes through.

Treat a `Pair URL` as a password while it is unused. Every start also logs a
pairing token and URL, so treat the deploy log as secret too. The logged URL uses
the container's private address, which is why setup creates a link with
`--base-url`. `t3 pair` has no such flag and prints the same private address.

T3 Connect is not set up. Its documented setup, `t3 up`, runs a systemd user
service, which the container lacks.

## Tailscale

The node keeps the same Tailscale IP and MagicDNS name on every start because its
identity lives on the `tunnel-state` volume. It changes only if the machine is
removed from the admin console or the volume is deleted, and then the next start
logs in as a new machine.

`TS_AUTH_ONCE=true` logs in with `TS_AUTHKEY` only when the volume holds no
identity, so the key can expire or be revoked after the first start. The node key
itself expires after 180 days by default, which logs the machine out until it is
re-authenticated; disabling key expiry on the machine avoids that. A tagged auth
key does the same automatically, since tagged machines have key expiry off.

The serve config is inline in `compose.yml`. `$${TS_CERT_DOMAIN}` is escaped for
Compose so that `containerboot` receives `${TS_CERT_DOMAIN}` and fills in the
node's own MagicDNS name.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `t3code-home` | `/home/ubuntu` | The `t3` CLI and its downloaded versions, T3 Code's state and paired devices, agent CLIs and their logins |
| `t3code-workspace` | `/workspace` | Repositories the agents work on |
| `tunnel-state` | `/var/lib/tailscale` | The Tailscale node identity, which keeps its IP and name |

## Image

- The CLI lives at `~/.local/bin/t3`, a symlink into `~/.t3/runtime/versions` on
  the home volume, so an update survives a redeploy. To update, run `t3 update`
  in a shell, then restart the app. The running server keeps the old version
  until it restarts.
- `init: true` reaps the agent and terminal processes the server leaves behind,
  since the server would otherwise be PID 1.
- The `ubuntu` user has passwordless `sudo`. Anyone who pairs already has a shell
  as that user.
