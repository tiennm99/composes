# openclaw doctor findings

State of `openclaw doctor` on the miti-sg deployment after the migration from
the old Temp service, as of release 2026.9.8.

## Live-config workaround to undo

On ARM64, 2026.9.8 looks for the image's Playwright Chromium only under
`chrome-linux64/` and `chrome-linux/`, but the ARM64 build lives in
`chrome-linux-arm64/`. Upstream `main` already searches that directory
(`extensions/browser/src/browser/chrome.executables.ts`). Until a release
carries it, the live config points at the binary directly:

```
browser.executablePath = /home/node/.cache/ms-playwright/chromium-1243/chrome-linux-arm64/chrome
```

The path names the Playwright build (`chromium-1243`), so it breaks when an
image update ships a newer Chromium, and doctor will report the browser as
missing again. Once a release auto-detects the ARM64 build, remove the
override:

```sh
node openclaw.mjs config unset browser.executablePath
```

The same session also set `browser.headless=true` and
`browser.noSandbox=true`. Chromium aborts inside this container with its
sandbox enabled, and the container has no display. These two stay.

## Notes that remain, by design

| Note | Why it stays |
| --- | --- |
| Session SQLite: 31 deferred historical transcripts | Daily 03:00 cron runs from May–June 2026 (one prompt, one reply each) plus one probe, whose header ID differs from the file name. Upstream: no action needed when expected conversations are present; do not edit receipts to silence it. |
| Gateway: service management skipped | Docker supervises the process, not OpenClaw. |
| Host desktop: disabled | Optional desktop lab, not used. |
| Security: bound to `lan` | Required in a container behind Coolify's proxy; auth is the gateway token. Fires for any non-loopback bind. |
| GitHub projects | Optional; set `gateway.controlUi.github.token` only if private-repo search is wanted. |
