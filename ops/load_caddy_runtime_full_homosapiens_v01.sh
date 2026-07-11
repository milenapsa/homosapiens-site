#!/usr/bin/env sh
set -eu

echo "HOMOSAPIENS_CADDY_RUNTIME_LOAD_V01_START"
C=media-studio-caddy
NET=gateway-health_default
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
apk add --no-cache curl >/dev/null 2>&1 || true

for s in homosapiens-site homosapiens-lex-api homosapiens-lex-search homosapiens-lex-datajud media-studio-api; do
  docker network connect "$NET" "$s" >/dev/null 2>&1 || true
done

docker cp "$C:/etc/caddy/Caddyfile" "/tmp/Caddyfile.before-runtime-load-$STAMP" || true

cat > /tmp/Caddyfile.runtime <<'EOF'
{
    email milena@peterle.adv.br
}

actions.homosapiens.id {
    reverse_proxy media-studio-api:8000
}

api.homosapiens.id, juridica.peterle.adv.br {
    reverse_proxy homosapiens-lex-api:8080
}

lex.homosapiens.id {
    handle /v1/search* {
        reverse_proxy homosapiens-lex-search:8080
    }

    handle /v1/sources* {
        reverse_proxy homosapiens-lex-search:8080
    }

    handle /v1/datajud* {
        reverse_proxy homosapiens-lex-datajud:8080
    }

    handle /datajud* {
        reverse_proxy homosapiens-lex-datajud:8080
    }

    handle {
        reverse_proxy homosapiens-lex-api:8080
    }
}

homosapiens.id, www.homosapiens.id {
    reverse_proxy homosapiens-site:80
}
EOF

docker cp /tmp/Caddyfile.runtime "$C:/tmp/Caddyfile.runtime"
docker exec "$C" caddy validate --config /tmp/Caddyfile.runtime --adapter caddyfile

# In this container, reload can return a non-zero default-config warning even after posting to admin API.
docker exec "$C" caddy reload --config /tmp/Caddyfile.runtime --adapter caddyfile || true

sleep 5

echo "TEST_SITE_HTTPS"
docker run --rm --network "$NET" curlimages/curl:8.11.1 -ksS --connect-to homosapiens.id:443:media-studio-caddy:443 -o /dev/null -w 'SITE_HTTPS=%{http_code} SIZE=%{size_download}\n' https://homosapiens.id/ || true
echo "TEST_SITE_HTTP"
docker run --rm --network "$NET" curlimages/curl:8.11.1 -sS -o /dev/null -w 'SITE_HTTP=%{http_code} REDIRECT=%{redirect_url} SIZE=%{size_download}\n' -H 'Host: homosapiens.id' http://media-studio-caddy/ || true
echo "TEST_LEX_HEALTH"
docker run --rm --network "$NET" curlimages/curl:8.11.1 -ksS --connect-to lex.homosapiens.id:443:media-studio-caddy:443 -o /dev/null -w 'LEX_HEALTH=%{http_code} SIZE=%{size_download}\n' https://lex.homosapiens.id/health || true
echo "TEST_API_HEALTH"
docker run --rm --network "$NET" curlimages/curl:8.11.1 -ksS --connect-to api.homosapiens.id:443:media-studio-caddy:443 -o /dev/null -w 'API_HEALTH=%{http_code} SIZE=%{size_download}\n' https://api.homosapiens.id/health || true

echo "BACKUP=/tmp/Caddyfile.before-runtime-load-$STAMP"
echo "HOMOSAPIENS_CADDY_RUNTIME_LOAD_V01_OK"
