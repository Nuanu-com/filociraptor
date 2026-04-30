#!/bin/bash


#BRIEF
#Script backup Odoo database dan filestore, lalu upload ke DigitalOcean Spaces. Mengirim notifikasi ke Telegram jika berhasil atau gagal.

DATE=$(date +%F)
BACKUP_DIR="/backup/odoo"

#sesuaikan
DB_NAME=""
DB_USER=""

#sesuaikan
FILESTORE=""
REMOTE_PATH="nuanu-odoo-backup:nuanu-odoo-backup/odoo-backup"

#sesuaikan
BOT_TOKEN=""
CHAT_ID=""

send_telegram() {
    MESSAGE="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${MESSAGE}" \
        -d parse_mode="HTML" > /dev/null
}

fail_exit() {
    send_telegram "❌ <b>Odoo Backup FAILED</b>%0AHost: $(hostname)%0ADate: ${DATE}%0AError: $1"
    echo "ERROR: $1"
    exit 1
}

mkdir -p "$BACKUP_DIR" || fail_exit "Cannot create backup directory"

echo "=== START BACKUP $DATE ==="

pg_dump -U "$DB_USER" -Fc "$DB_NAME" > "$BACKUP_DIR/db-$DATE.dump" \
    || fail_exit "Database dump failed"

tar -czf "$BACKUP_DIR/filestore-$DATE.tar.gz" "$FILESTORE" \
    || fail_exit "Filestore backup failed"

tar -czf "$BACKUP_DIR/odoo-$DATE.tar.gz" \
    "$BACKUP_DIR/db-$DATE.dump" \
    "$BACKUP_DIR/filestore-$DATE.tar.gz" \
    || fail_exit "Combine backup failed"

rclone copy "$BACKUP_DIR/odoo-$DATE.tar.gz" "$REMOTE_PATH" \
    || fail_exit "Upload to DigitalOcean failed"

find "$BACKUP_DIR" -type f -mtime +7 -delete

BACKUP_SIZE=$(du -h "$BACKUP_DIR/odoo-$DATE.tar.gz" | awk '{print $1}')

send_telegram "✅ <b>Odoo Backup SUCCESS</b>%0AHost: $(hostname)%0ADatabase: ${DB_NAME}%0ADate: ${DATE}%0ASize: ${BACKUP_SIZE}%0ACloud: DigitalOcean Spaces"

echo "=== BACKUP DONE $DATE ==="