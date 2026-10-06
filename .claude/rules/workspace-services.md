# Workspace services

A service someone works *inside* — an editor, a coding agent, anything with a
shell — gets exactly two named volumes: one for the container user's home
directory, one mounted at `/workspace`. The home volume holds settings,
credentials and CLI logins; `/workspace` holds the code. Point whatever
variable selects the working directory at `/workspace`.

`code-server`, `code-server-lsio`, `paseo` and `webtop` all follow this. A service with no
human inside it does not — an agent such as `hermes` or `openclaw` keeps the
volume layout of its official Docker guide.

The split is so that wiping one does not take the other. Reinstalling an editor
should not cost you a repository, and deleting a repository should not cost you
your extensions and logins.

Check who owns `/workspace` on a fresh volume. Docker creates it `root:root`
unless the image ships the directory, and an image that drops to a non-root
user will not be able to write there. `code-server`, `code-server-lsio` and `webtop` need an
explicit `chown` for this reason; `paseo` does not.
