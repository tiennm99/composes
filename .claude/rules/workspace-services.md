# Workspace services

A service someone works *inside* — an editor, a coding agent, anything with a
shell — gets exactly two named volumes: one for the container user's home
directory, one for the code. The home volume holds settings, credentials and
CLI logins; the workspace volume holds the code. Point whatever variable
selects the working directory at the workspace mount.

A headless service mounts the workspace volume at `~/workspace`, lowercase,
inside the container user's home (`/home/<user>/workspace`), nested over the
home volume. `code-server`, `orca` and `t3code` follow this. A service with no
human inside it does not — an agent such as `hermes` or `openclaw` keeps the
volume layout of its official Docker guide.

The split is so that wiping one does not take the other. Reinstalling an editor
should not cost you a repository, and deleting a repository should not cost you
your extensions and logins.

Check who owns the workspace mount point on a fresh volume. Docker creates it
`root:root` unless the image ships the directory, and an image that drops to a
non-root user will not be able to write there. Create the directory in the
image, owned by the container user.
