# Known noise: `xdg-open` stack trace on start

Applies to `opencode/compose.yml`.

The container logs a Bun stack trace ending in
`Executable not found in $PATH: "xdg-open"` on every start. `opencode web`
tries to open the UI in a local browser; there isn't one. It is noise — the
server is already listening by then, and the container keeps running.

Installing `xdg-utils` would silence it at the cost of pulling X11 in and
tripling the image, which is not worth it for a log line.
