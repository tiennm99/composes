# Found issues

Issues seen while using the Zellij web client (v0.45.1) in the browser,
recorded on 2026-10-22 for later work. The service is in `zellij/`.

## Open

### Browser shortcuts never reach Zellij

Browsers keep Ctrl+T, Ctrl+W, Ctrl+N and Ctrl+Tab for themselves, and a page
in a normal tab cannot take them back. Zellij's default keys collide with
them: Ctrl+T (tab mode) and Ctrl+N (resize mode) open a browser tab or window
instead.

Ways around it:

| Route | Browsers | Notes |
| --- | --- | --- |
| Install Zellij as an app and use its window | Chrome, Edge | Most likely fix. The web client ships a manifest with `"display": "standalone"`, so the browser offers "Install page as app". Chrome stopped filtering Ctrl+W/N/T in app windows ([Chromium review](https://codereview.chromium.org/9701108/)); Kasm and code-server rely on it. Google does not document it, so test it. |
| Keyboard Lock API in JS fullscreen | Chrome 68+, Edge 79+ | The page must call `navigator.keyboard.lock()` after `requestFullscreen()`, with a permission prompt since Chrome 130 ([Chrome docs](https://developer.chrome.com/docs/capabilities/web-apis/keyboard-lock)). Zellij's client never calls it, so F11 gains nothing; it needs an upstream change. |
| Rebind Zellij's keys to Alt combinations | All | The only route in Firefox, which reserves these keys ([bug 1052569](https://bugzil.la/1052569)) and has neither app windows on Linux nor Keyboard Lock. |

Next: install the app in Chrome or Edge and retest Ctrl+T, Ctrl+N and
Ctrl+G there.

### Ctrl+G opens Firefox's find bar

Ctrl+G is Firefox's "find next". The Unlock-First preset puts unlock on
Ctrl+G, so in Firefox it opens the find bar instead. Zellij's key handler
(`hasModifiersToHandle` in `zellij-client/assets/app.js`) calls
`preventDefault` itself only for two or more modifiers or Meta, and leaves
single-Ctrl keys to xterm.js. Why Firefox still saw the key was not traced.

Rebinding unlock to Alt+G worked as a workaround; the config was then reset
to the defaults at the user's request. Backups of the Unlock-First config,
with Ctrl+G and with Alt+G, are in `~/.config/zellij/` in the home volume.

### Deleting a session from the session list seems to do nothing

Not a server fault; the session manager's keys are easy to miss:

- `Delete` (forward delete; Fn+Delete on a Mac) kills the selected running
  session. Backspace only edits the search box.
- `Ctrl+D` kills every other running session.
- The session you are attached to cannot be killed from the list. In the web
  client, opening `/` itself starts a session to show the list, so each visit
  adds one that cannot delete itself.

From a shell, `zellij kill-session <name>`, `zellij delete-session <name>`
and `zellij kill-all-sessions -y` always work.

Next: confirm whether Fn+Delete works for the user. If the extra session per
visit to `/` is a nuisance, look at how the welcome session is started.

### Lag while typing

The container was idle (0.15% CPU, 96 MiB) with no input errors in
`/tmp/zellij-1000/zellij-log/zellij.log`, so the server is not the cause.
Candidates: the broken `TERM` below (fixed), Vietnamese input methods that
send a backspace and a replacement for each composed character (each one a
round trip over the WebSocket), or network latency.

Next: retest with the input method off now that `TERM` is fixed.

## Fixed

### Backspace moved the cursor right

Zellij panes got `TERM=unknown` because the container has no TTY, and zsh had
no terminfo to move the cursor left. Fixed in `7f510ae` by setting
`TERM=xterm-256color` in the image.
