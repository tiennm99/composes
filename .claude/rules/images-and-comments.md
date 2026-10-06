# Images and comments

## Installing software in an image

Follow the upstream project's own documented install method, or the one the
community has settled on. Do not hand-roll a download, and do not take a stale
distro package just because `apt install` is shorter — check what version it
actually gives you first.

Where it gets installed depends on the kind of service. In a workspace service
(see `workspace-services.md`), install tools into a location that survives a
redeploy — the container user's home volume, such as `~/.local/bin` — not into
the image. The
exception is a system package that is more than a single binary — shared
libraries, a daemon, anything that hooks into `/etc` or the system paths. That
goes in the image, through the system package manager. Every other service
installs into the image.

## Comments in compose files, Dockerfiles and scripts

This holds for every file in a service directory, not just the compose file.

A comment says *what* a section installs, configures or does, in a line or
two. It does not explain *why*. Reasons — why not the distro package, why that
directory, why a version is pinned, why a step runs here and not there, what
would break if it were simplified — go in the service's `README.md`, where
they can be read in full and where someone deciding whether to change
something will actually look.

So: no rationale, no trade-offs, no cautionary notes in the file itself. When a
choice needs defending, write the defence in the README and let the header
comment point at it. Keep the README current whenever a file changes, otherwise
the reasoning is simply lost rather than relocated.
