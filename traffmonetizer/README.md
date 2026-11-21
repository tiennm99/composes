# traffmonetizer

[TraffMonetizer](https://traffmonetizer.com) bandwidth-sharing client, defined
in `compose.yml` with `restart: always`. It
only makes outbound connections, so there is no port to map a domain to.

`restart: always` instead of `unless-stopped` is on purpose: the client should
be restarted as often as possible. Docker brings it back even after a manual
stop once the daemon or host restarts. The Coolify app also has no watch path
for the same reason, so every push to the repository redeploys it.

`IMAGE_TAG` picks the image for the host architecture. It defaults to
`latest`, which is amd64 only; ARM hosts set `arm64v8` (or `arm32v7`).

## Environment

| Variable | Purpose |
| --- | --- |
| `IMAGE_TAG` | Image tag matching the host architecture: `latest` (amd64, default), `arm64v8` or `arm32v7`. |
| `TOKEN` | Application token from the TraffMonetizer dashboard. Passed both as an environment variable and on the `start accept --token` command line. |

## Storage

None — the client keeps no state worth persisting.

## Aiven Runtime

Aiven Runtime builds apps from source and refuses a Compose service that only
has `image:`. Pick `traffmonetizer/compose.aiven.yaml` as the manifest: it
builds `Dockerfile`, which wraps the upstream image and adds a static busybox
shell so `TOKEN` is read at start-up rather than baked into the image. Add
`TOKEN` as a secret in the app's settings and leave ports empty.

The Dockerfile uses the `latest` tag, which is amd64 only; use `arm64v8` if
the Runtime builder is ARM.
