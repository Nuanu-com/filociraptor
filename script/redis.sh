#!/bin/bash
set -e

REDIS_PASS="RAND_PASS"

echo "Updating system..."
apt update
apt install redis-server -y

echo "Backing up Redis config..."
cp /etc/redis/redis.conf /etc/redis/redis.conf.backup.$(date +%F-%H%M%S)

echo "Writing Redis config..."
cat > /etc/redis/redis.conf <<EOF
bind 0.0.0.0
protected-mode yes
port 6379
tcp-backlog 511

timeout 0
tcp-keepalive 300

daemonize no
supervised systemd
pidfile /run/redis/redis-server.pid

loglevel notice
logfile /var/log/redis/redis-server.log

databases 16

dir /var/lib/redis

save 900 1
save 300 10
save 60 10000

appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec

maxmemory 6gb
maxmemory-policy noeviction

latency-monitor-threshold 100

requirepass ${REDIS_PASS}
EOF

echo "Enabling Redis auto-start..."
systemctl enable redis-server

echo "Restarting Redis..."
systemctl restart redis-server

echo "Checking Redis status..."
systemctl --no-pager status redis-server

echo "Testing Redis..."
redis-cli -a "${REDIS_PASS}" ping

echo "Done."
echo "Redis installed and configured."
echo "Password: ${REDIS_PASS}"
