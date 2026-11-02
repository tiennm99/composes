# cloudflared

[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)
connector. It dials out to Cloudflare, so it needs no inbound port, and serves
whatever the tunnel routes in the Cloudflare dashboard or API.

Deploy one per server, each with its own tunnel. No domain is set in Coolify:
the hostname belongs to the tunnel, not to Traefik.

## Environment

`TUNNEL_TOKEN` is required and fails fast if unset. It is the connector token
of a remotely managed tunnel, and it grants control of that tunnel.

## Reaching the host

`extra_hosts` maps `host.docker.internal` to the Docker host, so a tunnel can
route to a service on the host without host networking. For SSH on the host,
route the public hostname to `ssh://host.docker.internal:22`.

## Browser SSH

Put a Cloudflare Access application of type SSH on the hostname to get a
terminal in the browser after login. Access requires the login email's prefix
to match the server username, so `user@example.com` logs in as `user`.

Short-lived certificates avoid pasting a private key into the browser. Generate
the application's certificate authority in Cloudflare, then trust its public
key in `sshd` with `TrustedUserCAKeys`.

Browser rendering rejects Service Auth and Bypass policies, so a client that
cannot complete a browser login needs a different route to `sshd`.
