# composes

Personal docker compose collection. One directory per service, each holding
`compose.yml`, a committed `.env.example`, and a gitignored `.env`.

## Deployment target

Services are deployed through Coolify and Dokploy, not plain `docker compose`
on a host. The platform owns the parts a standalone compose file would declare
itself.

## Intentional omissions — do not "fix" these

These are deliberate, not oversights. Do not flag them as defects or add them
unprompted:

- **No `ports:`.** Coolify and Dokploy attach the container to their proxy
  network and map a domain to the internal port. Publishing a port is redundant
  and would additionally expose it on the host.
- **No `restart:` policy.** The platform manages the container lifecycle.
- **No `container_name:`.** Let Compose derive it from the directory.

More generally: these files are tuned to one person's setup and are not meant
to be portable, standard, or turnkey. Prefer leaving a service minimal over
adding hardening or convention that the platform already provides.

## Secrets

Every service reads secrets from a sibling `.env`. Never commit one — the root
`.gitignore` covers `.env`/`*.env` and re-includes `.env.example`. Keep
`.env.example` in sync whenever a compose file gains or drops a variable.
