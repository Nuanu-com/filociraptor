#!/bin/bash

echo "======================================================"
echo "            ADD NEW NGINX SITE (INTERACTIVE)"
echo "            WITH OPTIONAL SSL & REDIRECT"
echo "======================================================"
echo ""

# Check nginx installed
if ! command -v nginx &> /dev/null; then
    echo "❌ Nginx is not installed! Install Nginx first."
    exit 1
fi

read -p "Enter domain name (example: mydomain.com): " DOMAIN

echo "Select site type:"
select TYPE in "Reverse Proxy" "Static Website"; do
    case $TYPE in
        "Reverse Proxy") SITE_TYPE=proxy; break;;
        "Static Website") SITE_TYPE=static; break;;
        *) echo "Invalid selection. Try again.";;
    esac
done

if [ "$SITE_TYPE" = "proxy" ]; then
    read -p "Enter backend port (example: 3000): " PORT
fi

if [ "$SITE_TYPE" = "static" ]; then
    read -p "Enter web root (default: /var/www/$DOMAIN/html): " ROOT
    ROOT=${ROOT:-/var/www/$DOMAIN/html}
fi

echo ""
echo "Enable SSL for this site?"
select SSL in "Yes" "No"; do
    case $SSL in
        Yes ) ENABLE_SSL=true; break;;
        No ) ENABLE_SSL=false; break;;
    esac
done

if [ "$ENABLE_SSL" = true ]; then
    read -p "Enter email for Let's Encrypt: " EMAIL

    echo "Force redirect HTTP -> HTTPS?"
    select REDIRECT in "Yes" "No"; do
        case $REDIRECT in
            Yes ) ENABLE_REDIRECT=true; break;;
            No ) ENABLE_REDIRECT=false; break;;
        esac
    done
fi

CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"

echo ""
echo "Creating Nginx site configuration..."

# Proxy or static site config
if [ "$SITE_TYPE" = "proxy" ]; then
sudo tee $CONFIG_PATH > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
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
    sudo mkdir -p $ROOT
    sudo chown -R $USER:$USER $ROOT

    echo "<h1>$DOMAIN - Static Site Ready</h1>" | sudo tee "$ROOT/index.html"

sudo tee $CONFIG_PATH > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN www.$DOMAIN;

    root $ROOT;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
fi

echo ""
echo "Enabling site and reloading Nginx..."
sudo ln -s $CONFIG_PATH /etc/nginx/sites-enabled/ 2>/dev/null
sudo nginx -t && sudo systemctl reload nginx

SSL_STATUS="Not Enabled"

# SSL INSTALLATION
if [ "$ENABLE_SSL" = true ]; then
    echo ""
    echo "----------------------------------------------"
    echo " Installing Certbot and Creating SSL Certificate"
    echo "----------------------------------------------"

    sudo apt install certbot python3-certbot-nginx -y

    if [ "$ENABLE_REDIRECT" = true ]; then
        sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --redirect
    else
        sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos
    fi

    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer

    SSL_STATUS="SSL Enabled"
fi

echo ""
echo "======================================================"
echo "           SITE SUCCESSFULLY CREATED"
echo "======================================================"
echo " Domain      : $DOMAIN"
echo " Type        : $SITE_TYPE"
echo " SSL Status  : $SSL_STATUS"
if [ "$SITE_TYPE" = "proxy" ]; then
echo " Proxy Port  : $PORT"
else
echo " Root Path   : $ROOT"
fi
echo "======================================================"
