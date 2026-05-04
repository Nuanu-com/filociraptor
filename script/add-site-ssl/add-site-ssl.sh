#!/bin/bash
set -eE -o pipefail

trap 'echo "❌ Error at line $LINENO. Script stopped."; exit 1' ERR

# ===== TELEGRAM CONFIG (SET YOUR VALUES HERE) =====
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"

send_telegram_alert() {
    local MESSAGE="$1"

    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d "chat_id=$TELEGRAM_CHAT_ID" \
        -d "text=$MESSAGE" \
        -d "parse_mode=HTML" >/dev/null || true
}

# ===== START =====
echo "======================================================"
echo "        ADD NEW NGINX SITE WITH SSL + FORWARDING"
echo "======================================================"

if ! command -v nginx >/dev/null 2>&1; then
    echo "❌ Nginx is not installed!"
    exit 1
fi

read -rp "Enter base domain (example: mydomain.com): " BASE_DOMAIN

[ -z "$BASE_DOMAIN" ] && { echo "❌ Domain required"; exit 1; }

# ===== DOMAIN OPTION =====
echo ""
echo "Select domain option:"
echo "1) Root domain only"
echo "2) Root domain + www"
echo "3) Subdomain only"
read -rp "Choice [1-3]: " DOMAIN_OPTION

case "$DOMAIN_OPTION" in
    1)
        DOMAIN="$BASE_DOMAIN"
        SERVER_NAMES="$BASE_DOMAIN"
        CERTBOT_DOMAINS=(-d "$BASE_DOMAIN")
        ;;
    2)
        DOMAIN="$BASE_DOMAIN"
        SERVER_NAMES="$BASE_DOMAIN www.$BASE_DOMAIN"
        CERTBOT_DOMAINS=(-d "$BASE_DOMAIN" -d "www.$BASE_DOMAIN")
        ;;
    3)
        read -rp "Enter subdomain (example: app.$BASE_DOMAIN): " SUBDOMAIN
        [ -z "$SUBDOMAIN" ] && { echo "❌ Subdomain required"; exit 1; }

        DOMAIN="$SUBDOMAIN"
        SERVER_NAMES="$SUBDOMAIN"
        CERTBOT_DOMAINS=(-d "$SUBDOMAIN")
        ;;
    *)
        echo "❌ Invalid option"; exit 1 ;;
esac

# ===== SITE TYPE =====
echo ""
echo "Select site type:"
echo "1) Reverse Proxy"
echo "2) Static Website"
read -rp "Choice [1-2]: " TYPE_OPTION

case "$TYPE_OPTION" in
    1) SITE_TYPE="proxy" ;;
    2) SITE_TYPE="static" ;;
    *) echo "❌ Invalid option"; exit 1 ;;
esac

# ===== PROXY CONFIG =====
if [ "$SITE_TYPE" = "proxy" ]; then
    echo ""
    echo "Select forwarding target:"
    echo "1) Localhost"
    echo "2) IP Address"
    echo "3) Hostname"
    read -rp "Choice [1-3]: " TARGET_OPTION

    case "$TARGET_OPTION" in
        1) TARGET_HOST="127.0.0.1" ;;
        2) read -rp "Enter IP: " TARGET_HOST ;;
        3) read -rp "Enter hostname: " TARGET_HOST ;;
        *) echo "❌ Invalid option"; exit 1 ;;
    esac

    read -rp "Enter backend port: " PORT

    [[ ! "$PORT" =~ ^[0-9]+$ ]] && { echo "❌ Invalid port"; exit 1; }
fi

# ===== STATIC CONFIG =====
if [ "$SITE_TYPE" = "static" ]; then
    read -rp "Web root [/var/www/$DOMAIN/html]: " ROOT
    ROOT=${ROOT:-/var/www/$DOMAIN/html}
fi

# ===== SSL =====
echo ""
echo "Enable SSL?"
echo "1) Yes"
echo "2) No"
read -rp "Choice [1-2]: " SSL_OPTION

case "$SSL_OPTION" in
    1) ENABLE_SSL=true ;;
    2) ENABLE_SSL=false ;;
    *) echo "❌ Invalid option"; exit 1 ;;
esac

ENABLE_REDIRECT=false

if [ "$ENABLE_SSL" = true ]; then
    read -rp "Enter email for Let's Encrypt: " EMAIL
    [ -z "$EMAIL" ] && { echo "❌ Email required"; exit 1; }

    echo ""
    echo "Force HTTP -> HTTPS?"
    echo "1) Yes"
    echo "2) No"
    read -rp "Choice [1-2]: " REDIRECT_OPTION

    case "$REDIRECT_OPTION" in
        1) ENABLE_REDIRECT=true ;;
        2) ENABLE_REDIRECT=false ;;
        *) echo "❌ Invalid option"; exit 1 ;;
    esac
fi

CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
ENABLED_PATH="/etc/nginx/sites-enabled/$DOMAIN"

echo ""
echo "Creating Nginx config..."

# ===== NGINX CONFIG =====
if [ "$SITE_TYPE" = "proxy" ]; then
sudo tee "$CONFIG_PATH" >/dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $SERVER_NAMES;

    location / {
        proxy_pass http://$TARGET_HOST:$PORT;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

else
    sudo mkdir -p "$ROOT"
    sudo chown -R "$USER:$USER" "$ROOT"

    echo "<h1>$DOMAIN - Ready</h1>" | sudo tee "$ROOT/index.html" >/dev/null

sudo tee "$CONFIG_PATH" >/dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $SERVER_NAMES;

    root $ROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
fi

# ===== ENABLE =====
sudo ln -sf "$CONFIG_PATH" "$ENABLED_PATH"

sudo nginx -t
sudo systemctl reload nginx

SSL_STATUS="Not Enabled"

# ===== SSL SETUP =====
if [ "$ENABLE_SSL" = true ]; then
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx

    if [ "$ENABLE_REDIRECT" = true ]; then
        sudo certbot --nginx "${CERTBOT_DOMAINS[@]}" \
            --email "$EMAIL" --agree-tos --redirect --non-interactive
    else
        sudo certbot --nginx "${CERTBOT_DOMAINS[@]}" \
            --email "$EMAIL" --agree-tos --non-interactive
    fi

    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer

    sudo certbot renew --dry-run

    SSL_STATUS="SSL Enabled"
fi

# ===== SUCCESS TELEGRAM =====
SUCCESS_MESSAGE="✅ <b>Nginx Site Created</b>

🌐 Domain: $DOMAIN
🧭 Server: $SERVER_NAMES
📦 Type: $SITE_TYPE
🔐 SSL: $SSL_STATUS
"

send_telegram_alert "$SUCCESS_MESSAGE"

# ===== FINAL OUTPUT =====
echo ""
echo "======================================================"
echo "           SITE SUCCESSFULLY CREATED"
echo "======================================================"
echo "Domain      : $DOMAIN"
echo "Server Name : $SERVER_NAMES"
echo "Type        : $SITE_TYPE"
echo "SSL Status  : $SSL_STATUS"
echo "======================================================"