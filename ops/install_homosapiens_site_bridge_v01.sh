#!/usr/bin/env bash
set -Eeuo pipefail

echo "HOMOSAPIENS_SITE_BRIDGE_V01_START"

REPO_RAW="https://raw.githubusercontent.com/milenapsa/homosapiens-site/main"
APP_ROOT="/srv/homosapiens-site"
RELEASE="$APP_ROOT/releases/$(date -u +%Y%m%dT%H%M%SZ)"
CURRENT="$APP_ROOT/current"
CONTAINER="homosapiens-site"
NETWORK="gateway-health_default"
CADDY_CONTAINER="media-studio-caddy"

command -v docker >/dev/null
docker network inspect "$NETWORK" >/dev/null
docker ps --format '{{.Names}}' | grep -qx "$CADDY_CONTAINER"

echo "1) Criando release estática..."
mkdir -p "$RELEASE/assets"
curl -fsSL "$REPO_RAW/site/index.html" -o "$RELEASE/index.html"
curl -fsSL "$REPO_RAW/site/assets/style.css" -o "$RELEASE/assets/style.css"
ln -sfn "$RELEASE" "$CURRENT"

echo "2) Subindo container do portal..."
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" --restart unless-stopped --network "$NETWORK" -v "$CURRENT:/usr/share/nginx/html:ro" nginx:alpine >/dev/null
sleep 3

echo "3) Backup e atualização do Caddy..."
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
docker exec "$CADDY_CONTAINER" sh -lc "cp /etc/caddy/Caddyfile /tmp/Caddyfile.before-homosapiens-site-$STAMP || true"
docker cp "$CADDY_CONTAINER":/etc/caddy/Caddyfile /tmp/Caddyfile.homosapiens.current

python3 - <<'PY'
from pathlib import Path
p = Path("/tmp/Caddyfile.homosapiens.current")
text = p.read_text(encoding="utf-8", errors="ignore")
def remove_block(src, needles):
    for needle in needles:
        i = src.find(needle)
        if i >= 0:
            j = src.find("{", i)
            if j < 0: continue
            depth=0; k=j
            while k < len(src):
                if src[k] == "{": depth += 1
                elif src[k] == "}":
                    depth -= 1
                    if depth == 0:
                        src = src[:i].rstrip() + "\n\n" + src[k+1:].lstrip()
                        break
                k += 1
    return src
text = remove_block(text, ["homosapiens.id, www.homosapiens.id", "homosapiens.id {", "www.homosapiens.id {"])
block = "homosapiens.id, www.homosapiens.id {\n    reverse_proxy homosapiens-site:80\n}\n"
p.write_text(text.rstrip() + "\n\n" + block, encoding="utf-8")
PY

docker cp /tmp/Caddyfile.homosapiens.current "$CADDY_CONTAINER":/etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy fmt --overwrite /etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy validate --config /etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy reload --config /etc/caddyfile

echo "4) Self-test local por Host header..."
curl -ksS -o /tmp/homosapiens-site-local -w "LOCAL_HOST_HEADER_HTTP=%{http_code} SIZE=%{size_download}\n" -H "Host: homosapiens.id" http://127.0.0.1/ || true
head -c 300 /tmp/homosapiens-site-local || true
echo

echo "5) Containers:"
docker ps --format 'CONTAINER={{.Names}} STATUS={{.Status}} PORTS={{.Ports}}' | grep -E 'homosapiens-site|media-studio-caddy' || true

echo "HOMOSAPIENS_SITE_BRIDGE_V01_OK"
