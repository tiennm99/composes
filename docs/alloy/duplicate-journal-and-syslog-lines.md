# Duplicate journal and syslog lines

Applies to `alloy/compose.yml`.

## Symptom

The same log line arrives in Loki twice: once from `loki.source.journal`, once
from `loki.source.file`.

## Cause

Where rsyslog mirrors journald into `/var/log/syslog` — the Debian and Ubuntu
default — the journal and file pipelines both ship it.

## Fix

Drop one source on those hosts. On systemd-only stacks the file-based one is
the redundant one.
