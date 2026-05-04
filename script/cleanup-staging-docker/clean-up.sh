#!/bin/bash

TELEGRAM_BOT_TOKEN="ISI_BOT_TOKEN"
TELEGRAM_CHAT_ID="ISI_CHAT_ID_GROUP"

DISK_PATH="/mnt/volume_staging_add_1"
THRESHOLD=90

HOSTNAME=$(hostname)
DATE_NOW=$(date '+%Y-%m-%d %H:%M:%S')

send_telegram() {
  MESSAGE="$1"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d parse_mode="HTML" \
    --data-urlencode text="${MESSAGE}" > /dev/null
}

DISK_PERCENT=$(df -h "$DISK_PATH" | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_USAGE=$(df -h "$DISK_PATH" | awk 'NR==2 {print $3 " used / " $2 " total / " $4 " available"}')

OFF_CONTAINERS=$(docker ps -a --filter "status=exited" --filter "status=dead" --format "{{.Names}}" | sort)

if [ -z "$OFF_CONTAINERS" ]; then
  OFF_CONTAINERS="None"
fi

if [ "$DISK_PERCENT" -ge "$THRESHOLD" ]; then
  BEFORE_AVAILABLE=$(df -B1 "$DISK_PATH" | awk 'NR==2 {print $4}')

  send_telegram "⚠️ <b>Disk Alert</b>
Host: <b>${HOSTNAME}</b>
Time: ${DATE_NOW}

Disk Path: <code>${DISK_PATH}</code>
Usage: <b>${DISK_PERCENT}%</b>
Space: ${DISK_USAGE}

<b>Off/Error Containers:</b>
<pre>${OFF_CONTAINERS}</pre>

Running cleanup:
<code>docker image prune -a</code>
<code>docker builder prune -a</code>"

  IMAGE_PRUNE_OUTPUT=$(docker image prune -a -f 2>&1)
  IMAGE_STATUS=$?

  BUILDER_PRUNE_OUTPUT=$(docker builder prune -a -f 2>&1)
  BUILDER_STATUS=$?

  AFTER_AVAILABLE=$(df -B1 "$DISK_PATH" | awk 'NR==2 {print $4}')
  CLEANED_BYTES=$((AFTER_AVAILABLE - BEFORE_AVAILABLE))
  CLEANED_HUMAN=$(numfmt --to=iec --suffix=B "$CLEANED_BYTES")

  DISK_PERCENT_AFTER=$(df -h "$DISK_PATH" | awk 'NR==2 {print $5}')
  DISK_USAGE_AFTER=$(df -h "$DISK_PATH" | awk 'NR==2 {print $3 " used / " $2 " total / " $4 " available"}')

  if [ "$IMAGE_STATUS" -eq 0 ] && [ "$BUILDER_STATUS" -eq 0 ]; then
    STATUS="✅ Success"
  else
    STATUS="❌ Failed"
  fi

  send_telegram "🧹 <b>Docker Cleanup Report</b>
Host: <b>${HOSTNAME}</b>
Status: <b>${STATUS}</b>

Cleaned Space: <b>${CLEANED_HUMAN}</b>

Before: <b>${DISK_PERCENT}%</b>
After: <b>${DISK_PERCENT_AFTER}</b>
Space After: ${DISK_USAGE_AFTER}

Image prune status: ${IMAGE_STATUS}
Builder prune status: ${BUILDER_STATUS}"
fi