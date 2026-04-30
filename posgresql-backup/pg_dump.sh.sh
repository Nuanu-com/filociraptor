#!/usr/bin/env bash
set -e

# ===== TELEGRAM CONFIG =====
BOT_TOKEN=""
CHAT_ID=""

# ===== DB CONFIG =====
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="woodenfish"
DB_USER="user_odoo"

# ===== BACKUP CONFIG =====
BACKUP_DIR="/var/backups/postgresql"
RETENTION_DAYS=30
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

# ===== FUNCTIONS =====
send_telegram() {
  local MESSAGE="$1"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="$MESSAGE" \
    -d parse_mode="Markdown" \
    > /dev/null
}

# ===== START =====
mkdir -p "$BACKUP_DIR"

send_telegram "🟡 *PostgreSQL Backup Started*
📦 Database: \`$DB_NAME\`
🕒 Time: \`$(date)\`"

# ===== BACKUP PROCESS =====
if pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -F c -Z 9 "$DB_NAME" -f "$BACKUP_FILE"; then
  FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

  send_telegram "✅ *PostgreSQL Backup SUCCESS*
📦 Database: \`$DB_NAME\`
📁 File: \`$(basename "$BACKUP_FILE")\`
💾 Size: *$FILE_SIZE*
🕒 Time: \`$(date)\`"
else
  send_telegram "❌ *PostgreSQL Backup FAILED*
📦 Database: \`$DB_NAME\`
🕒 Time: \`$(date)\`
🚨 Please check server logs!"

  exit 1
fi

# ===== CLEAN OLD BACKUPS =====
find "$BACKUP_DIR" -type f -name "*.dump" -mtime +$RETENTION_DAYS -delete
