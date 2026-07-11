# Inventário — ponte GitHub para homosapiens.id

## Diagnóstico

Não havia repositório dedicado `milenapsa/homosapiens-site` para edição e publicação do portal raiz `homosapiens.id`.

Foram identificados repositórios operacionais relacionados à Lex e instaladores, mas não uma fonte canônica do portal público raiz.

## Decisão

Criar um repositório dedicado para o portal público:

- GitHub: `milenapsa/homosapiens-site`
- Escopo: portal institucional público do ecossistema HomoSapiens
- Publicação: via instalador A4 assistido na VPS
- Produção: `homosapiens.id` e `www.homosapiens.id`

## Gates

Publicação real exige aprovação explícita, backup do Caddy, container dedicado, teste local por Host header e evidência técnica.

## Observação DNS

Se `homosapiens.id` ainda apontar para serviço Hostinger/Sites e não para a VPS, o instalador pode preparar a VPS, mas o domínio público só mudará após ajuste DNS.
