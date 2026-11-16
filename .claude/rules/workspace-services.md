# Workspace services

A service someone works *inside* — an editor, a coding agent, a desktop,
anything with a shell — gets one named volume for the container user's home
directory. Settings, credentials, CLI logins and the code all live there; the
code goes in `~/workspace`, lowercase, as a plain folder in that volume. Point
whatever variable selects the working directory at it. `code-server`, `orca`,
`t3code` and `webtop` (home `/config`) follow this.

A service with no human inside it does not — an agent such as `hermes` or
`openclaw` keeps the volume layout of its official Docker guide.

Make sure `~/workspace` comes out owned by the container user. A `WORKDIR`
set after `USER` in the image creates it with that owner, and Docker seeds an
empty home volume from the image. A home volume that already has content is
not seeded, so a service that must have the folder creates it at startup as
that user (`mkdir -p` in the entrypoint); a service with neither, such as
`webtop` on its stock image, leaves it to the user to create. No image needs a
build step only to fix its ownership.
