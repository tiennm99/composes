# orca

[Orca](https://github.com/stablyai/orca) run headless with `orca serve`, as a
Remote Orca Server. The server owns the projects, worktrees, terminals and
agents; a browser, the Orca desktop app or the Orca mobile app connects to it
and is only the UI. Upstream ships no Docker image, so a local `Dockerfile`
builds one from `ubuntu:24.04`, and `entrypoint.sh` downloads the Orca
AppImage into `$HOME` on first start.

Orca is reached through a public domain, so a client needs no VPN. See
[Exposure](#exposure).

## Setup

1. Point the domain at port `6768`. Set `ORCA_PAIRING_ADDRESS` to that domain
   as `wss://orca.example.com`, then deploy.
2. Open the deploy log and find the lines printed after `Orca server ready`:

   ```
   Web client URL: https://orca.example.com/web-index.html#pairing=...
   Pairing URL: orca://pair?code=...
   ```

3. **Browser:** open the `Web client URL`. **Desktop app:** paste the
   `Pairing URL` into **Settings → Remote Orca Servers → Add Server**.
4. **Mobile:** set `ORCA_PAIRING=mobile` and redeploy. The log then prints a
   QR code and a mobile `Pairing URL`. In Orca Mobile choose **Pair** and scan
   the QR code or paste the link.
5. Once every client is paired, set `ORCA_PAIRING=none` and redeploy, so later
   starts print no link.
6. From a terminal inside Orca, install and log in to the agent CLIs you want
   (`claude`, `codex`, …), and add accounts with `orca account add --agent
   claude`.

A start without `none` prints a link. An unused link stays the same across
restarts, and a new token is created only after the previous one has been used.
Paired clients keep their grant until it is revoked under **Settings → Remote
Orca Servers → Shared Server Access**, so a redeploy does not disconnect them.

## Environment

| Variable | Purpose |
| --- | --- |
| `ORCA_PAIRING_ADDRESS` | The address clients dial, as a `wss://` URL on the domain. Required. |
| `ORCA_PAIRING` | Which link the start prints: `runtime` (browser and desktop, the default), `mobile` or `none`. |
| `SERVICE_HOSTNAME` | Container hostname, shown as the host name in the prompt. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity for agents and terminals. |

`ORCA_PAIRING_ADDRESS` is only what the server advertises; it still binds
`0.0.0.0:6768`. Without it the links point at `127.0.0.1`, which only works
inside the container. Given a `wss://` address, Orca turns it into the
`https://` web client URL itself, and the proxy carries both the page and the
WebSocket on the one port.

The web client URL is only printed in `runtime` mode, and the mobile app needs
a mobile-scoped link, so the two cannot come from one start; hence the
`ORCA_PAIRING` switch. A second `orca-ide serve` from a terminal inside the
container cannot mint a link either: it refuses while this server holds the
profile. `none` starts without a new link, for when every client is paired.

The links are printed rather than hidden because the server runs in the
foreground without `--supervise`; Orca redacts them only when supervised. The
container's restart policy replaces that supervisor. Treat the logs as secret:
the link is the credential.

`HOST` is set to `SERVICE_HOSTNAME` because Coolify injects `HOST=0.0.0.0`,
which zsh would otherwise show as the prompt's host name.

## Exposure

The port is public through the domain so that clients need no VPN. Upstream
advises against forwarding the Orca port directly to the internet and accepts
an authenticated tunnel, so an authenticating proxy in front of the domain is
worth adding; test that the desktop and mobile apps can still get through it.

Without one, the pairing token is the only barrier. It is 192 random bits, and
traffic is end-to-end encrypted above the WebSocket, so the proxy cannot read
it. The web client and the pre-login WebSocket are open to anyone, and Orca caps
connections at 128 WebSocket and 256 TCP, so a flood can lock clients out.

The token stays valid after it is used, so a link in the logs keeps working
until it is revoked, not just until first use. Revoking it also removes the
devices paired from it, and they have to pair again. Anyone who can read the
container's logs can therefore pair.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `orca-home` | `/home/ubuntu` | The Orca AppImage and its extracted cache, Orca's state and paired devices, agent CLIs and their logins |
| `orca-workspace` | `/workspace` | Repositories the agents work on |

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
