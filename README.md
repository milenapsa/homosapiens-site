# homosapiens-site

Portal público do ecossistema HomoSapiens / homosapiens.id.

Este repositório é a fonte única para editar o portal institucional e publicar na VPS.

## Estrutura

- `site/` — arquivos públicos do portal.
- `ops/publish_homosapiens_site_vps_v03.sh` — publicador idempotente na VPS.
- `ops/rollback_caddy_homosapiens_site_v01.sh` — rollback do Caddy usando backup persistente.
- `docs/` — inventário e evidência operacional.

## Produção

- Domínio: `https://homosapiens.id`
- Alias: `https://www.homosapiens.id`
- VPS: `76.13.226.21`
- Container: `homosapiens-site`
- Proxy: `media-studio-caddy`

Publicação real é operação A4 e deve gerar evidência técnica.
