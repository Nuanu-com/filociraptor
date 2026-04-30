#!/usr/bin/env bash
set -e

DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="woodenfish"
DB_USER="user_odoo"

BACKUP_DIR="/var/backups/postgresql"
RETENTION_DAYS=7

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

mkdir -p "$BACKUP_DIR"

pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -F c -Z 9 "$DB_NAME" -f "$BACKUP_FILE"

find "$BACKUP_DIR" -type f -name "*.dump" -mtime +$RETENTION_DAYS -delete

echo "Backup success: $BACKUP_FILE"
