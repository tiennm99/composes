#!/usr/bin/with-contenv bash
# shellcheck shell=bash
# Write the WebUI login from WEBUI_USERNAME and WEBUI_PASSWORD into qBittorrent's config.
set -euo pipefail

python3 - <<'EOF'
import base64
import hashlib
import os

conf = "/config/qBittorrent/qBittorrent.conf"
salt = os.urandom(16)
key = hashlib.pbkdf2_hmac("sha512", os.environ["WEBUI_PASSWORD"].encode(), salt, 100000)
values = {
    "Username": os.environ["WEBUI_USERNAME"],
    "Password_PBKDF2": "@ByteArray({}:{})".format(
        base64.b64encode(salt).decode(), base64.b64encode(key).decode()
    ),
}

with open(conf) as f:
    lines = f.read().splitlines()

if "[WebUI]" not in lines:
    lines += ["", "[WebUI]"]
start = lines.index("[WebUI]") + 1
end = next((i for i in range(start, len(lines)) if lines[i].startswith("[")), len(lines))
section = [l for l in lines[start:end] if l.split("=", 1)[0] not in values]
while section and not section[-1]:
    section.pop()
section += ["{}={}".format(k, v) for k, v in values.items()]
if end < len(lines):
    section.append("")
lines[start:end] = section

with open(conf, "w") as f:
    f.write("\n".join(lines) + "\n")
EOF
