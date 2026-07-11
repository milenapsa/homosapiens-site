#!/usr/bin/env sh
set -eu

echo "HOMOSAPIENS_SITE_PUBLISH_V03_START"

SITE_CONTAINER="${SITE_CONTAINER:-homosapiens-site}"
CADDY_CONTAINER="${CADDY_CONTAINER:-media-studio-caddy}"
REPO_ARCHIVE="${REPO_ARCHIVE:-https://github.com/milenapsa/homosapiens-site/archive/refs/heads/main.tar.gz}"
SITE_VOLUME="${SITE_VOLUME:-homosapiens_site_content}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

echo "STAMP=$STAMP"
echo "REPO_ARCHIVE=$REPO_ARCHIVE"

apk add --no-cache curl tar gzip python3 >/dev/null 2>&1 || true

echo "1) Preflight"
docker ps --format '{{.Names}}' | grep -qx "$CADDY_CONTAINER"
mkdir -p "$BACKUP_DIR"

echo "2) Fetch GitHub source"
rm -rf /tmp/homosapiens-src /tmp/homosapiens-site.tar.gz
mkdir -p /tmp/homosapiens-src
curl -fsSL "$REPO_ARCHIVE" -o /tmp/homosapiens-site.tar.gz
tar -xzf /tmp/homosapiens-site.tar.gz -C /tmp/homosapiens-src --strip-components=1
test -f /tmp/homosapiens-src/site/index.html
test -f /tmp/homosapiens-src/site/assets/style.css

echo "3) Update static volume from Git source"
docker volume create "$SITE_VOLUME" >/dev/null
docker run --rm -v "$SITE_VOLUME:/site" -v "/tmp/homosapiens-src/site:/src:ro" alpine:3.20 sh -lc 'rm -rf /site/* && cp -a /src/. /site/ && chmod -R a+rX /site'

echo "4) Recreate site container"
docker rm -f "$SITE_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$SITE_CONTAINER" --restart unless-stopped -v "$SITE_VOLUME:/usr/share/nginx/html:ro" nginx:1.27-alpine >/dev/null
sleep 3

echo "5) Attach site to every Caddy network"
docker inspect "$CADDY_CONTAINER" > /tmp/caddy.inspect.json
python3 - <<'PY' > /tmp/caddy.networks
import json
d=json.load(open('/tmp/caddy.inspect.json'))[0]
for name in d.get('NetworkSettings',{}).get('Networks',{}).keys():
    print(name)
PY

if [ ! -s /tmp/caddy.networks ]; then
  echo "ERROR: no Caddy networks found"
  exit 2
fi

while IFS= read -r net; do
  [ -n "$net" ] || continue
  echo "CONNECT_NETWORK=$net"
  docker network connect "$net" "$SITE_CONTAINER" >/dev/null 2>&1 || true
done < /tmp/caddy.networks

echo "6) Backup and patch Caddy"
BACKUP_FILE="$BACKUP_DIR/Caddyfile.before-homosapiens-site-$STAMP"
docker cp "$CADDY_CONTAINER:/etc/caddy/Caddyfile" "$BACKUP_FILE"
cp "$BACKUP_FILE" /tmp/Caddyfile.new

python3 - <<'PY'
from pathlib import Path
p = Path('/tmp/Caddyfile.new')
text = p.read_text(encoding='utf-8', errors='ignore')
begin = '# BEGIN HOMOSAPIENS_SITE'
end = '# END HOMOSAPIENS_SITE'
while begin in text and end in text:
    a = text.find(begin)
    b = text.find(end, a)
    if b < 0:
        break
    b2 = text.find('\n', b)
    text = text[:a].rstrip() + '\n\n' + (text[b2+1:].lstrip() if b2 >= 0 else '')
block = '''
# BEGIN HOMOSAPIENS_SITE
homosapiens.id, www.homosapiens.id {
    reverse_proxy homosapiens-site:80
}
# END HOMOSAPIENS_SITE
'''
p.write_text(text.rstrip() + '\n\n' + block + '\n', encoding='utf-8')
PY

docker cp /tmp/Caddyfile.new "$CADDY_CONTAINER:/etc/caddy/Caddyfile"
docker exec "$CADDY_CONTAINER" caddy fmt --overwrite /etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy validate --config /etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy reload --config /etc/caddyfile

echo "7) Tests"
FIRST_NET="$(head -n 1 /tmp/caddy.networks)"

echo "TEST_DIRECT_SITE"
docker run --rm --network "$FIRST_NET" curlimages/curl:8.11.1 -fsS "http://$SITE_CONTAINER/" | head -c 220
echo

echo "TEST_CADDY_HTTP"
docker run --rm --network "$FIRST_NET" curlimages/curl:8.11.1 -sS -o /tmp/out -w 'HTTP=%{http_code} REDIRECT=%{redirect_url} SIZE=%{size_download}\n' -H 'Host: homosapiens.id' "http://$CADDY_CONTAINER/" || true

echo "TEST_CADDY_HTTPS"
docker run --rm --network "$FIRST_NET" curlimages/curl:8.11.1 -ksS --connect-to "homosapiens.id:443:$CADDY_CONTAINER:443" -o /tmp/out2 -w 'HTTPS=%{http_code} REDIRECT=%{redirect_url} SIZE=%{size_download}\n' https://homosapiens.id/ || true

echo "8) Containers"
docker ps --format 'CONTAINER={{.Names}} STATUS={{.Status}} PORTS={{.Ports}}' | grep -E 'homosapiens-site|media-studio-caddy' || true

echo "BACKUP_FILE=$BACKUP_FILE"
echo "HOMOSAPIENS_SITE_PUBLISH_V03_OK"
