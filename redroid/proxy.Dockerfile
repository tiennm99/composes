FROM caddy:2-alpine

# Basic-auth reverse proxy in front of ws-scrcpy.
COPY Caddyfile /etc/caddy/Caddyfile
COPY proxy-entrypoint.sh /usr/local/bin/proxy-entrypoint.sh
ENTRYPOINT ["/bin/sh", "/usr/local/bin/proxy-entrypoint.sh"]
