# homosapiens-site

Portal público do ecossistema HomoSapiens/homosapiens.id.

Fonte Git para editar o portal institucional e publicar de forma controlada na VPS.

## Estrutura

- `site/` — arquivos públicos do portal.
- `ops/install_homosapiens_site_bridge_v01.sh` — instalador/publicador A4 assistido para a VPS.
- `ops/Caddyfile.fragment` — bloco de Caddy para `homosapiens.id` e `www.homosapiens.id`.
- `docs/` — inventário operacional e próximos passos.

## Regra operacional

Preparar não é publicar. Publicar exige execução do instalador na VPS, teste e evidência técnica.
Não guardar senhas, tokens, certificados ou chaves neste repositório.
