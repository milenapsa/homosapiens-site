# Fonte única de publicação — homosapiens.id

Este repositório é a fonte canônica do portal público `homosapiens.id`.

## Fluxo

```text
GitHub: milenapsa/homosapiens-site
  → site/
  → ops/publish_homosapiens_site_vps_v03.sh
  → VPS: container homosapiens-site
  → Caddy: homosapiens.id / www.homosapiens.id
```

## Publicação

A publicação real é A4: altera VPS/Caddy/produção e exige evidência técnica.

Comando de publicação, quando autorizado na VPS:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v homosapiens_ops_backups:/backups \
  docker:27-cli sh -lc "apk add --no-cache curl >/dev/null && curl -fsSL https://raw.githubusercontent.com/milenapsa/homosapiens-site/main/ops/publish_homosapiens_site_vps_v03.sh -o /tmp/publish.sh && sh /tmp/publish.sh"
```

## Rollback Caddy

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v homosapiens_ops_backups:/backups \
  docker:27-cli sh -lc "apk add --no-cache curl >/dev/null && curl -fsSL https://raw.githubusercontent.com/milenapsa/homosapiens-site/main/ops/rollback_caddy_homosapiens_site_v01.sh -o /tmp/rollback.sh && sh /tmp/rollback.sh"
```

## Evidência esperada

```text
Valid configuration
HOMOSAPIENS_SITE_PUBLISH_V03_OK
HTTP=308 ou HTTP=200
HTTPS=200
CONTAINER=homosapiens-site STATUS=Up
```

## Regras

- Não guardar segredo neste repositório.
- Alterações em `site/` só viram produção após publicação na VPS.
- DNS raiz `@` e `www` ficam apontados para a VPS.
- Caddy é o ponto público de roteamento.
