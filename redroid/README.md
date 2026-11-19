# redroid

[Redroid](https://github.com/remote-android/redroid-doc) runs Android in a
container, and [ws-scrcpy](https://github.com/NetrisTV/ws-scrcpy) shows and
controls it in a browser. The `redroid` container is Android; `web` is
ws-scrcpy, which reaches Android over adb on the app network.

## Setup

1. **Host:** load Android's binder driver before deploying:

   ```sh
   modprobe binder_linux devices="binder,hwbinder,vndbinder"
   ```

   This lasts until the next reboot. To load it at every boot, put
   `binder_linux` in `/etc/modules-load.d/redroid.conf` and
   `options binder_linux devices=binder,hwbinder,vndbinder` in
   `/etc/modprobe.d/redroid.conf`.
2. Point the domain at the `web` service on port `8000`.
3. Turn on HTTP basic auth for the app in Coolify. ws-scrcpy has no login of
   its own.

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
