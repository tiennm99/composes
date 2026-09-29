# traffmonetizer

[TraffMonetizer](https://traffmonetizer.com) bandwidth-sharing client, defined
in `docker-compose.yml` with `container_name: tm` and `restart: always`. It
only makes outbound connections, so there is no port to map a domain to.

The image tag is `arm64v8`. Change it to match the host architecture.

## Environment

| Variable | Purpose |
| --- | --- |
| `TOKEN` | Application token from the TraffMonetizer dashboard. Passed both as an environment variable and on the `start accept --token` command line. |

## Storage

None — the client keeps no state worth persisting.
