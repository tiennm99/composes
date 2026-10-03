---
name: debug-service
description: Debug a service in this compose collection — read its compose definition, pull deploy status and logs from Coolify, check out the matching upstream source into sources/, and prove the root cause before changing the service directory. Use when a service here fails to deploy, crashes, or misbehaves. Not for bugs in the upstream project's own code or in repos outside this collection.
---

# Debug a service

Find why one service in this repository fails, with evidence, and fix it in
that service's directory. Prove the cause before editing anything; stop
investigating as soon as it is proven.

## Boundaries

- Read `<service>/.env.example`, never `<service>/.env`; it holds real secrets.
  Do not copy tokens, passwords or keys from logs into reports.
- Read-only Coolify calls need no confirmation. `control` (start, stop,
  restart) and `deploy` affect a live service: ask the user first.
- Never commit anything under `sources/`, and never fix a service by editing
  upstream code there.

## 1. Frame the issue

Name the service directory (`<service>/`), the observed symptom and the
expected behaviour. If the user did not name the service, match the symptom
against the root `README.md` table.

## 2. Read the local definition

Read `<service>/compose.yml`, `<service>/README.md`, `<service>/.env.example`,
and `<service>/Dockerfile` with any files it copies. For each container note
the image and tag (or the Dockerfile's `FROM`), environment variable names,
volumes and command.

Run `git log --oneline -10 -- <service>/`; a recent change is the first suspect.

## 3. Collect runtime evidence

Coolify has two MCP servers, `miti-jp` and `miti-sg`; the service may live on
either.

1. `search_resources` with the service name on both servers.
2. For a failed deploy: `list_deployments`, then `get_deployment` with
   `include_log_summary=true`.
3. `get_logs` only when the resource is running; otherwise follow the
   returned reason and `next_tools` rather than retrying.
4. `list_env_keys` to confirm every variable in `.env.example` is set
   (names only; values are never returned).

If neither server has it, the service is likely on Dokploy, which has no MCP
here: ask the user to paste the container logs and deploy output.

Keep the exact error lines; they are the search keys for step 5. If the logs
and compose definition already prove the cause (a missing variable, a wrong
path), skip to step 6.

## 4. Check out the upstream source

Pick the repositories that matter:

- `image:` services: the image's upstream repo, found from the registry page,
  the image's `org.opencontainers.image.source` label, or the service README.
- `build: .` services: the Dockerfile in the service directory is local code;
  also take the `FROM` image's repo, and for a wrapper image (linuxserver,
  for example) the application repo it packages, if the error comes from it.
- Closed-source images have no repo. Say so and work from logs and vendor
  docs only.

Resolve the version the container runs. Use an exact tag directly. For a
moving tag (`latest`, `:4`), take the version printed in the logs; failing
that, the latest release (`gh release view -R <owner>/<repo> --json tagName`),
and say it is inferred.

Clone into `sources/<owner>/<repo>`:

```sh
git clone --depth 1 --branch <tag> https://github.com/<owner>/<repo> sources/<owner>/<repo>
```

If the checkout exists, switch it instead of cloning again:

```sh
git -C sources/<owner>/<repo> fetch --depth 1 origin tag <tag>
git -C sources/<owner>/<repo> checkout <tag>
```

## 5. Trace the cause

- Search the checkout for the exact error text, the failing config key, or
  the environment variable name.
- Read how the code consumes that variable, path or flag, and compare it with
  what `compose.yml` and the Dockerfile provide.
- When it looks like a regression, check the upstream changelog and issues
  for that version.

State the cause with evidence: the log line, the source file and line, and
the mismatch with the service definition. If evidence is inconclusive, report
the hypotheses and what would distinguish them instead of guessing a fix.

## 6. Fix and report

Change only `<service>/`, following this repository's `CLAUDE.md`: comments
say *what*, reasons go in the service `README.md`, `.env.example` stays in sync
and in compose order. Pin an exact version only when the newer release is
proven broken, and write what breaks in the README.

Report the cause, the evidence, the change, and how to verify after redeploy.
Ask before redeploying. Leave `sources/` checkouts in place for next time.
