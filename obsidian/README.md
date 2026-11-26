# obsidian

[Obsidian](https://obsidian.md) desktop in the browser, from the
[LinuxServer image](https://docs.linuxserver.io/images/docker-obsidian),
streamed by Selkies. It runs all the time, so plugins such as Self-hosted
LiveSync and Obsidian Git keep working on the server while every other device
is off. The image ships `git`, which Obsidian Git uses.

## Setup

1. Set `CUSTOM_USER` and `PASSWORD`.
2. Map the domain to port `3000` and deploy.
3. Open the domain and log in with `CUSTOM_USER` / `PASSWORD`.
4. Open or create a vault under `~/workspace`, for example
   `~/workspace/notes`.

Port `3000` serves plain HTTP and must sit behind the proxy, which adds HTTPS.
The image's own HTTPS port `3001`, with a self-signed certificate, is unused.

## Git

Clone the notes repo into `~/workspace` from Obsidian's terminal or Obsidian
Git, and keep the git login in the home volume (a credential helper or an SSH
key under `~/.ssh`), so it survives a redeploy.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `CUSTOM_USER` / `PASSWORD` | — | Login for the web GUI |
| `TZ` | `Asia/Ho_Chi_Minh` | Timezone, also for commit times |
| `TITLE` | optional | Browser tab title |

`CUSTOM_USER` and `PASSWORD` are required. Without `PASSWORD` the image serves
Obsidian, with a terminal, to anyone who opens the domain.

`PUID`/`PGID` are pinned to `1000` in `compose.yml`, so files in `/config`
keep the same owner across recreates.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `obsidian-config` | `/config` | Home directory: Obsidian settings and plugins, git login, and vaults in `~/workspace` |

## Resources

`shm_size: 1gb` is upstream's setting for Electron apps, which run out of
shared memory at Docker's 64 MB default.

## Image

`latest` is LinuxServer's only moving tag for this image.
