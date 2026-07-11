# Status da publicação VPS — homosapiens.id

Data: 2026-07-11 (UTC)


## Resumo

O portal `homosapiens.id` foi publicado na VPS com fonte no repositório `homosapiens-site`.

O fluxo final ér:

- GitHub: `milenapsa/homosapiens-site`
- VPS: container `homosapiens-site`
- Caddy: `media-studio-caddy`
- Domínio: `homosapiens.id` e `www.homosapiens.id`

## Evidéncias

### Containers


```text
CONTAINER=homosapiens-site STATUS=Up
CONTAINER=media-studio-caddy STATUS=Up
```

### Caddy

```text
Valid configuration
HOMOSAPIENS_CADDY_PATCH_V01_OK
```

### DNS


```text
@     A   76.13.226.21
www  CNAME homosapiens.id.
```

## Observações de operação

- O primeiro publicador `HOMOSAPIENS_SITE_PUBLISH_VPS_V01` subiu o contúdo e o container corretamente, mas teve erro em um trecho auxiliar de patch do Caddy. A execução prosseguiu com configuração válida.
- A correção do bloco do Caddy foi consolidada por `ops/patch_caddy_homosapiens_site_v01.sh`.
- O log indicou `HOMOSAPIENS_CADDY_PATCH_V01_OK` e ponto de backup do Caddy em `/tmp/Caddyfile.before-homosapiens-site-20260711T021755Z`.

## Próximos passos

- Aguardar disseminação/cache DNS e testar `homosapiens.id` e `www.homosapiens.id` no navegador.
- Se necessário, rodar novo publicador para puxar alterações do GitHub.
- Métricas/logs/rollback devem ser feitos com evidência técnica.
