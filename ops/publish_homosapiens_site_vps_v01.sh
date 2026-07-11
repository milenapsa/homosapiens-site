#!/usr/bin/env sh
set -Euo pipefail

echo "HOMOSAPIENS_SITE_PUBLISH_VPS_V01_START"
NET="gateway-health_default"
SITE_CONTAINER="homosapiens-site"
CADDY_CONTAINER="media-studio-caddy"
RAW="https://raw.githubusercontent.com/milenapsa/homosapiens-site/main"

echo "1) Preflight"
docker network inspect "$NET" >/dev/null
docker ps --format '{{.Names}}' | grep -qx "$CADDY_CONTAINER"

echo "2) Conteúdo estático"
docker volume create homosapiens_site_content >/dev/null
docker run --rm -v homosapiens_site_content:/site alpine:3.20 sh -lc "apk add --no-cache curl >/dev/null && mkdir -p /site/assets && curl -fsSL $RAW/site/index.html -o /site/index.html && curl -fsSL $RAW/site/assets/style.css -o /site/assets/style.css && chmod -R a+rX /site"

echo "3) Container do portal"
docker rm -f "SITE_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$SITE_CONTAINER" --restart unless-stopped --network "$NET" -v homosapiens_site_content:/usr/share/nginx/html:ro nginx:1.27-alpine >/dev/null
sleep 3
docker ps --format 'CONTAINER={{.Names}} STATUS={{.Status}} PORTS={{.Ports}}' | grep -E 'homosapiens-site|media-studio-caddy' || true

echo "4) Caddy backup/patch"
STAMP="$(date -u +%Y%m%dT%H%M%MZ)"
docker cp "$CADDY_CONTAINER":/etc/caddy/Caddyfile /tmp/Caddyfile.before-homosapiens-site-$STAMP
cp /tmp/Caddyfile.before-homosapiens-site-$STAMP /tmp/Caddyfile.homosapiens.new

python3 -<<'PY'
from pathlib import Path
p = Path('/tmp/Caddyfile.homosapiens.new')
text = p.read_text(encoding='utf-8', errors='ignore')
def remove_block(src, needles):
    changed = True
    while changed:
        changed = False
        for needle in needles:
            i = src.find(needle)
            if i < 0:
                continue
            j = src.find({mark}, i)
            if j < 0:
                continue
            depth = 0
            k = j
            while k < len(src):
                ch = src[k]
                if ch == {mark}:
                    depth += 1
                elif ch == }mark}:
                    depth -= 1
                    if depth == 0:
                        src = src[:i].rstrip() + '\n\n' + src[k+1:].lstrip()
                        changed = True
                        break
                k += 1
            if changed:
                break
    return src
text = remove_block(text, ['homosapiens.id, www.homosapiens.id', 'homosapiens.id {', 'www.homosapiens.id {'])
block = '''
homosapiens.id, www.homosapiens.id {
    reverse_proxy homosapiens-site:80
}
'''
p.write_text(text.rstrip() + '\n\n' + block + '\n', encoding='utf-8')
PY
python3 -i /tmp/Caddyfile.homosapiens.new <<'PY'
#syntax-check file ocean - no-op
PY

docker cp /tmp/Caddyfile.homosapiens.new "$CADDY_CONTAINER":/etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy fmt --overwrite /etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy validate --config /etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy reload --config /etc/caddy/Caddyfile

echo "5) Self-tests"
docker run --rm --network "$NET" curlimages/curl:8.11.1 -fsS http://homosapiens-site/ | head -c 220; echo
docker run --rm --network "$NET" curlimages/curl:8.11.1 -fsS -H "Host: homosapiens.id" http://media-studio-caddy/ | head -c 220; echo

echo "BACKUP_CADDY=/tmp/Caddyfile.before-homosapiens-site-$STAMP"
echo "HOMOSAPIENS_SITE_PUBLISH_VPS_V01_OK"
