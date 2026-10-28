# orca

[Orca](https://github.com/stablyai/orca) run headless with `orca serve`, as a
Remote Orca Server. The server owns the projects, worktrees, terminals and
agents; a browser, the Orca desktop app or the Orca mobile app connects to it
and is only the UI. Upstream ships no Docker image, so a local `Dockerfile`
builds one from `ubuntu:24.04`, and `entrypoint.sh` downloads the Orca
AppImage into `$HOME` on first start.

Orca is reachable only on a Tailscale tailnet. A `tunnel` sidecar joins the
tailnet as its own machine and serves Orca over HTTPS at its MagicDNS name;
the service has no public domain. See [Exposure](#exposure).

## Setup

1. In the Tailscale admin console, enable MagicDNS and HTTPS certificates
   under **DNS**, and generate an auth key under **Settings → Keys**: not
   ephemeral, not reusable. Set it as `TS_AUTHKEY`, and set
   `ORCA_PAIRING_ADDRESS` to `wss://<TS_HOSTNAME>.<tailnet>.ts.net`, using
   the tailnet name shown under **DNS**. Give the app no domain, then deploy.
2. Under **Machines**, open the new `orca` machine and choose **Disable key
   expiry**.
3. Open the deploy log and find the lines printed after `Orca server ready`:

   ```
   Web client URL: https://orca.tailnet-name.ts.net/web-index.html#pairing=...
   Pairing URL: orca://pair?code=...
   ```

   Every client device must be on the same tailnet.
4. **Browser:** open the `Web client URL`. **Desktop app:** paste the
   `Pairing URL` into **Settings → Remote Orca Servers → Add Server**.
5. **Mobile:** set `ORCA_PAIRING=mobile` and redeploy. The log then prints a
   QR code and a mobile `Pairing URL`. In Orca Mobile choose **Pair** and scan
   the QR code or paste the link. Set `ORCA_PAIRING` back to `runtime`
   afterwards.
6. From a terminal inside Orca, install and log in to the agent CLIs you want
   (`claude`, `codex`, …), and add accounts with `orca account add --agent
   claude`.

Every start prints a fresh link and replaces the previous unused one. Clients
that already paired keep their own grant until it is revoked under **Settings
→ Remote Orca Servers → Shared Server Access**, so a redeploy does not
disconnect them.

## Environment

| Variable | Purpose |
| --- | --- |
| `ORCA_PAIRING_ADDRESS` | The address clients dial, as a `wss://` URL on the node's MagicDNS name. Required. |
| `ORCA_PAIRING` | Which link the start prints: `runtime` (browser and desktop, the default), `mobile` or `none`. |
| `SERVICE_HOSTNAME` | Container hostname, shown as the host name in the prompt. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity for agents and terminals. |
| `TS_AUTHKEY` | Tailscale auth key, used only for the node's first login. Required. |
| `TS_HOSTNAME` | Machine name on the tailnet, the first label of the MagicDNS name. Defaults to `orca`. |

`ORCA_PAIRING_ADDRESS` is only what the server advertises; it still binds
`0.0.0.0:6768`. Without it the links point at `127.0.0.1`, which only works
inside the container. Given a `wss://` address, Orca turns it into the
`https://` web client URL itself, and `tailscale serve` carries both the page
and the WebSocket on port 443.

The web client URL is only printed in `runtime` mode, and the mobile app needs
a mobile-scoped link, so the two cannot come from one start; hence the
`ORCA_PAIRING` switch. A second `orca-ide serve` from a terminal inside the
container cannot mint a link either: it refuses while this server holds the
profile. `none` starts without a new link, for when every client is paired.

The links are printed rather than hidden because the server runs in the
foreground without `--supervise`; Orca redacts them only when supervised. The
container's restart policy replaces that supervisor. Treat the deploy log as
secret while an unused link is in it: the link is the credential.

`HOST` is set to `SERVICE_HOSTNAME` because Coolify injects `HOST=0.0.0.0`,
which zsh would otherwise show as the prompt's host name.

## Exposure

Upstream advises against putting the Orca port on the public internet and
prefers Tailscale or a LAN, so the port is reached only through Tailscale.
The `tunnel` container runs `tailscaled` in userspace mode, with no extra
capabilities or `/dev/net/tun`, and `tailscale serve` terminates HTTPS with a
Let's Encrypt certificate for the MagicDNS name and proxies to `orca:6768`
on the app's own network. Nothing is published on the host or Coolify's
proxy. Orca still logs a warning about its `0.0.0.0` bind, which now only the
`tunnel` container can reach.

The pairing link is still written in plain text to the deploy log, so anyone
who can read that log while a link is unused can pair, from inside the
tailnet.

## Tailscale

The node keeps the same Tailscale IP and MagicDNS name on every start because
its identity lives on the `tunnel-state` volume. The address belongs to the
machine in the tailnet, not to the container; it changes only if the machine
is removed from the admin console or the volume is deleted, and then the next
start logs in as a new machine.

`TS_AUTH_ONCE=true` logs in with `TS_AUTHKEY` only when the volume holds no
identity, so the key can expire or be revoked after the first start. The node
key itself expires after 180 days by default, which logs the machine out
until it is re-authenticated; disabling key expiry on the machine avoids that.
A tagged auth key does the same automatically, since tagged machines have key
expiry off.

The serve config is inline in `compose.yml`. `$${TS_CERT_DOMAIN}` is escaped
for Compose so that `containerboot` receives `${TS_CERT_DOMAIN}` and fills in
the node's own MagicDNS name.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `orca-home` | `/home/ubuntu` | The Orca AppImage and its extracted cache, Orca's state and paired devices, agent CLIs and their logins |
| `orca-workspace` | `/workspace` | Repositories the agents work on |
| `tunnel-state` | `/var/lib/tailscale` | The Tailscale node identity, which keeps its IP and name |

The first start downloads the AppImage (about 250 MB) and Orca extracts it
into `~/.cache` (about 700 MB), so it takes a minute or more before the server
is ready. Later starts reuse both.

## Image

- The AppImage lives at `~/.local/bin/orca-ide`, on the home volume, not in
  the image. The AppImage is the Linux package that updates itself in place;
  in the image it would be stuck at the build-time version, and the `.deb`
  never updates itself at all. On the volume, an update applied from a paired
  client survives a redeploy. To force a fresh download, delete that file and
  restart.
- `APPIMAGE_EXTRACT_AND_RUN=1` starts the AppImage without FUSE, which a
  container does not have. This is the launch upstream tests in Docker.
- The Electron libraries and `xvfb` are the set upstream's headless Docker
  test installs. Orca starts its own Xvfb display when none is set; the dbus
  "Failed to connect to the bus" error at startup is harmless.
- `shm_size: 256m` matches upstream's test containers. Docker's 64 MB default
  is too small for Chromium, which backs Orca's browser panes.
- Orca disables the Electron sandbox by itself when user namespaces are
  unavailable, as in Docker, and reaps orphans when it runs as PID 1, so the
  compose file needs neither `--no-sandbox` nor `init: true`.
- Per-terminal memory limits (`ORCA_TERMINAL_MEMORY_MAX`) need systemd user
  scopes, which the container lacks; Orca skips them.
- The `ubuntu` user has passwordless `sudo`. Anyone who pairs already has a
  shell as that user.
