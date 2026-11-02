# t3code troubleshooting

Applies to `t3code/compose.yml`.

## Browser tabs and HTML previews do not start

The server logs this at every start:

```
This host blocks the sandbox T3's browser runs in, so browser tabs and HTML previews will not start.
```

The command it suggests, `t3 browser setup`, does not work in this container.
It writes an AppArmor profile to `/etc/apparmor.d`, which does not exist here,
and fails with `Could not write /etc/apparmor.d/t3-chrome-headless-shell`. The
profile would have to be on the host, which also has
`kernel.apparmor_restrict_unprivileged_userns=1`. The rest of the app works
without the browser, so the template leaves this as it is.

## `Claude Agent CLI health check failed`

This is logged until the Claude CLI is installed. It stopped after installing
the CLI and restarting the app.
