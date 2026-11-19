FROM caddy:2-alpine

# Basic-auth reverse proxy in front of ws-scrcpy.
COPY Caddyfile /etc/caddy/Caddyfile
