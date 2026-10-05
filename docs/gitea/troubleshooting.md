# gitea troubleshooting

Applies to `gitea/compose.yml`.

## Gitea cannot connect after changing `POSTGRES_PASSWORD`

Postgres sets the password only when it first initialises `db-data`. Changing
`POSTGRES_PASSWORD` later breaks Gitea's connection until the role is altered
to match:

```sh
docker compose exec db psql -U gitea -c "ALTER USER gitea PASSWORD '<new>';"
```

## A redeploy kills clones in progress

Gitea restarts and the clone dies with it. Avoid pushing to `gitea/`
while a large first mirror runs.
