# traffmonetizer

[TraffMonetizer](https://traffmonetizer.com) bandwidth-sharing client, defined
in `compose.yml` with `restart: always`. It
only makes outbound connections, so there is no port to map a domain to.

`restart: always` instead of `unless-stopped` is on purpose: the client should
be restarted as often as possible. Docker brings it back even after a manual
stop once the daemon or host restarts. The Coolify app also has no watch path
for the same reason, so every push to the repository redeploys it.

The image tag is `arm64v8`. Change it to match the host architecture.

## Environment

| Variable | Purpose |
| --- | --- |
| `TOKEN` | Application token from the TraffMonetizer dashboard. Passed both as an environment variable and on the `start accept --token` command line. |

## Storage

None — the client keeps no state worth persisting.
