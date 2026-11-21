# Aiven Runtime builds apps from a Dockerfile, not from a Compose `image:`.
# The upstream image has no shell, so a static busybox is added to expand
# TOKEN at start-up instead of baking it into the image.
FROM busybox:1-musl AS busybox

FROM traffmonetizer/cli_v2:latest
COPY --from=busybox /bin/busybox /bin/busybox
ENTRYPOINT ["/bin/busybox", "sh", "-c", "exec /usr/local/bin/cli start accept --token \"$TOKEN\""]
