FROM ghcr.io/selkies-project/selkies/desktop:latest-ubuntu26.04

# Workspace directory owned by the ubuntu user (uid/gid 1000).
USER 0
RUN mkdir -p /workspace && chown 1000:1000 /workspace
USER 1000
