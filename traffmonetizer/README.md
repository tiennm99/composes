# traffmonetizer

[TraffMonetizer](https://traffmonetizer.com) bandwidth-sharing client.

Uses `docker-compose.yml`, and sets `restart: always` and
`container_name: tm` — unlike the platform-managed services described in the
[root README](../README.md). Publishes no ports; the client only makes outbound
connections.

The image tag is `arm64v8`. Change it to match the host architecture.

## Environment

| Variable | Purpose |
| --- | --- |
| `TOKEN` | Application token from the TraffMonetizer dashboard. Passed both as an environment variable and on the `start accept --token` command line. |

## Storage

None — the client keeps no state worth persisting.
