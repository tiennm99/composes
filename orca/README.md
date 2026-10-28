# orca

[Orca](https://github.com/stablyai/orca) run headless with `orca serve`, as a
Remote Orca Server. The server owns the projects, worktrees, terminals and
agents; a browser, the Orca desktop app or the Orca mobile app connects to it
and is only the UI. Upstream ships no Docker image, so a local `Dockerfile`
builds one from `ubuntu:24.04`, and `entrypoint.sh` downloads the Orca
AppImage into `$HOME` on first start.

**Not production ready.** The Orca port is reachable from the public internet
through the domain, against upstream's advice, and the pairing link is printed
in plain text in the deploy log. See [Exposure](#exposure). Both are open
issues, not settled choices.

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
   the QR code or paste the link. Set `ORCA_PAIRING` back to `runtime`
   afterwards.
5. From a terminal inside Orca, install and log in to the agent CLIs you want
   (`claude`, `codex`, …), and add accounts with `orca account add --agent
   claude`.

Every start prints a fresh link and replaces the previous unused one. Clients
that already paired keep their own grant until it is revoked under **Settings
→ Remote Orca Servers → Shared Server Access**, so a redeploy does not
disconnect them.

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
`https://` web client URL itself, and Coolify's proxy carries both the page and
the WebSocket on the one port.

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

Open risk, not yet solved. Upstream advises against putting the Orca port on
the public internet and prefers Tailscale or a LAN. For now this setup exposes
it through the domain, so that a browser and a phone can reach it from
anywhere. What protects it today: every client needs a pairing link, each
paired client gets its own revocable token, and traffic is end-to-end
encrypted with the server's key. The static web client page itself is public,
and anything that reaches the port can attempt pairing. Orca logs a warning
about the `0.0.0.0` bind on every start.

The pairing link is also written in plain text to the deploy log, so anyone
who can read that log while a link is unused can pair.

A Cloudflare Access app in front of the domain would block the mobile app,
which cannot pass its login, so none is used yet.

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
