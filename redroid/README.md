# redroid

[Redroid](https://github.com/remote-android/redroid-doc) runs Android in a
container, and [ws-scrcpy](https://github.com/NetrisTV/ws-scrcpy) shows and
controls it in a browser. The `redroid` container is Android; `web` is
ws-scrcpy, which reaches Android over adb on the app network; `proxy` is
Caddy, which asks for a username and password and then forwards to `web`.

## Setup

1. **Host:** load Android's binder driver before deploying:

   ```sh
   modprobe binder_linux devices="binder,hwbinder,vndbinder"
   ```

   This lasts until the next reboot. To load it at every boot, put
   `binder_linux` in `/etc/modules-load.d/redroid.conf` and
   `options binder_linux devices=binder,hwbinder,vndbinder` in
   `/etc/modprobe.d/redroid.conf`.
2. Create the password hash; the password prompt does not echo:

   ```sh
   docker run --rm -it caddy:2-alpine caddy hash-password | tail -n 1 | tr -d '\r' | base64 -w0
   ```

3. Set the variables, then point the domain at the `proxy` service on port
   `80` and deploy.

## Variables

| Variable | Meaning |
| --- | --- |
| `BASIC_AUTH_USERNAME` | Login name for the page |
| `BASIC_AUTH_HASH` | The password's bcrypt hash, base64-encoded, from step 2 |

## Use

The page lists the device; open it to stream the screen and control it with
mouse and keyboard. Dropping an APK on the stream copies it to
`/data/local/tmp`; install it from the page's shell with
`pm install /data/local/tmp/<file>.apk`.

## Storage

`redroid-data` holds Android's `/data`: installed apps, their data and
settings.

## Why it is set up this way

- **Privileged:** Redroid needs it to mount binderfs and run Android's init.
  Root inside Android can therefore reach the host, which is why the page must
  stay behind authentication.
- **Caddy for the login:** ws-scrcpy has no login of its own, and Coolify's
  HTTP basic auth setting does not apply to compose apps. The `Caddyfile` is
  baked into a small image so the proxy does not depend on a bind mount.
- **Base64 hash:** a raw bcrypt hash is full of `$`, which compose would read
  as variables; Caddy accepts the base64-encoded form as well.
- **Android 15:** Android 16 requires the `ashmem` driver, which recent kernels
  no longer have. Android 15 runs with `androidboot.use_memfd=true` instead.
- **Software rendering:** `androidboot.redroid_gpu_mode=guest` draws on the
  CPU, for hosts without a usable GPU.
- **ws-scrcpy is built here:** upstream publishes no image, so the
  `Dockerfile` builds its `master` branch.
- **Node 22:** ws-scrcpy's `node-pty` dependency does not compile on newer
  Node releases.
- **adb reconnect loop:** `entrypoint.sh` retries `adb connect` every ten
  seconds, so the device reappears after Android boots or restarts.
