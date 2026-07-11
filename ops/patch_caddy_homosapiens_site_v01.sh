#!/usr/bin/env sh
set -eu
echo "HOMOSAPIENS_CADDY_PATCH_V01_START"
C="media-studio-caddy"
S="homosapiens-site"
NET="gateway-health_default"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
docker ps --format '{{.Names}}' | grep -qx "$C"
docker ps --format '{{.Names}}' | grep -qx "$S"
docker cp "$C":/etc/caddy/Caddyfile "/tmp/Caddyfile.before-homosapiens-site-$STAMP"
awk 'BEGIN{skip=0} /# BEGIN HOMOSAPIENS_SITE/{skip=1; next} /# END HOMOSAPIENS_SITE/{skip=0; next} !skip{print}' "/tmp/Caddyfile.before-homosapiens-site-$STAMP" > /tmp/Caddyfile.homosapiens.patch
cat >> /tmp/Caddyfile.homosapiens.patch <<'EOF'

# BEGIN HOMOSAPIENS_SITE
homosapiens.id, www.homosapiens.id {
    reverse_proxy homosapiens-site:80
}
# END HOMOSAPIENS_SITE
EOF
docker cp /tmp/Caddyfile.homosapiens.patch "$C":/etc/caddy/Caddyfile
docker exec "$C" caddy fmt --overwrite /etc/caddy/Caddyfile
docker exec "$C" caddy validate --config /etc/caddy/Caddyfile
docker exec "$C" caddy reload --config /etc/caddy/Caddyfile
docker run --rm --network "$NET" curlimages/curl:8.11.1 -fsS -H "Host: homosapiens.id" http://media-studio-caddy/ | head -c 220
echo
echo "BACKUP_CADDY=/tmp/Caddyfile.before-homosapiens-site-$STAMP"
echo "HOMOSAPIENS_CADDY_PATCH_V01_OK"
