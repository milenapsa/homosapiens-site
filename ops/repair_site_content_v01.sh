#!/usr/bin/env sh
set -eu

echo "HOMOSAPIENS_SITE_REPAIR_V01_START"
apk add --no-cache curl python3 >/dev/null 2>&1 || true

NET="${NET:-gateway-health_default}"
CADDY="${CADDY:-media-studio-caddy}"
SITE="${SITE:-homosapiens-site}"
VOL="${VOL:-homosapiens_site_content}"
RAW="${RAW:-https://raw.githubusercontent.com/milenapsa/homosapiens-site/main}"

echo "BEFORE"
docker ps --format 'CONTAINER={{.Names}} STATUS={{.Status}} PORTS={{.Ports}}' | grep -E 'homosapiens-site|media-studio-caddy' || true
docker inspect "$SITE" --format 'MOUNTS={{json .Mounts}}' 2>/dev/null || true

echo "UPDATE_CONTENT_VOLUME"
docker volume create "$VOL" >/dev/null
docker run --rm -v "$VOL:/site" alpine:3.20 sh -lc "
  apk add --no-cache curl >/dev/null &&
  rm -rf /site/* &&
  mkdir -p /site/assets &&
  curl -fsSL '$RAW/site/index.html' -o /site/index.html &&
  curl -fsSL '$RAW/site/assets/style.css' -o /site/assets/style.css &&
  chmod -R a+rX /site &&
  ls -la /site /site/assets
"

echo "RECREATE_SITE"
docker rm -f "$SITE" >/dev/null 2>&1 || true
docker run -d --name "$SITE" --restart unless-stopped --network "$NET" -v "$VOL:/usr/share/nginx/html:ro" nginx:1.27-alpine >/dev/null
sleep 3

echo "CONNECT_TO_CADDY_NETWORKS"
docker inspect "$CADDY" > /tmp/caddy.json
python3 - <<'PY' > /tmp/nets
import json
d=json.load(open('/tmp/caddy.json'))[0]
for n in d.get('NetworkSettings',{}).get('Networks',{}).keys():
    print(n)
PY

while IFS= read -r n; do
  [ -n "$n" ] || continue
  docker network connect "$n" "$SITE" >/dev/null 2>&1 || true
done < /tmp/nets

echo "TEST_DIRECT"
docker run --rm --network "$NET" curlimages/curl:8.11.1 -fsS "http://$SITE/" | head -c 260
echo

echo "TEST_CADDY_HTTPS"
docker run --rm --network "$NET" curlimages/curl:8.11.1 -ksS --connect-to "homosapiens.id:443:$CADDY:443" https://homosapiens.id/ | head -c 260
echo

echo "AFTER"
docker ps --format 'CONTAINER={{.Names}} STATUS={{.Status}} PORTS={{.Ports}}' | grep -E 'homosapiens-site|media-studio-caddy' || true

echo "HOMOSAPIENS_SITE_REPAIR_V01_OK"
