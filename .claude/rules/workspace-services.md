# Workspace services

A service someone works *inside* — an editor, a coding agent, a desktop,
anything with a shell — gets one named volume for the container user's home
directory. Settings, credentials, CLI logins and the code all live there; the
code goes in `~/workspace`, lowercase, as a plain folder in that volume. Point
whatever variable selects the working directory at it. `code-server`, `orca`,
`t3code` and `webtop` (home `/config`) follow this.

A service with no human inside it does not — an agent such as `hermes` or
`openclaw` keeps the volume layout of its official Docker guide.

Make sure `~/workspace` comes out owned by the container user. Create it at
startup as that user (`mkdir -p` in the entrypoint, then `cd` into it), and
keep the image's `WORKDIR` at home, not `~/workspace`: on a home volume that
already has content, Docker creates a missing `WORKDIR` as root before the
entrypoint runs. A service on a stock image with no entrypoint of its own,
such as `webtop`, leaves the folder to the user to create. No image needs a
build step only to fix its ownership.
