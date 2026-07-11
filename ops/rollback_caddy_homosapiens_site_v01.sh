#!/usr/bin/env sh
set -eu
echo "HOMOSAPIENS_SITE_ROLLBACK_CADDY_V01_START"
CADDY_CONTAINER="${CADDY_CONTAINER:-media-studio-caddy}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_FILE="${BACKUP_FILE:-}"
if [ -z "$BACKUP_FILE" ]; then
  BACKUP_FILE="$(ls -1t "$BACKUP_DIR"/Caddyfile.before-homosapiens-site-* 2>/dev/null | head -n 1 || true)"
fi
if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: backup file not found"
  echo "Available backups:"
  ls -la "$BACKUP_DIR" || true
  exit 2
fi
echo "RESTORE_FROM=$BACKUP_FILE"
docker ps --format '{{.Names}}' | grep -qx "$CADDY_CONTAINER"
docker cp "$BACKUP_FILE" "$CADDY_CONTAINER:/etc/caddy/Caddyfile"
docker exec "$CADDY_CONTAINER" caddy fmt --overwrite /etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy validate --config /etc/caddy/Caddyfile
docker exec "$CADDY_CONTAINER" caddy reload --config /etc/caddy/Caddyfile
echo "HOMOSAPIENS_SITE_ROLLBACK_CADDY_V01_OK"
