#!/bin/bash

echo "=========================================="
echo "   NGINX REVERSE PROXY INSTALLER"
echo "=========================================="

# Interactive Inputs
read -p "Enter your domain name (example: mydomain.com): " DOMAIN
read -p "Enter backend service port (example: 3000): " PORT

echo "Do you want to install Let's Encrypt SSL now?"
select SSL_OPTION in "Yes" "No (install later)"; do
    case $SSL_OPTION in
        Yes ) INSTALL_SSL=true; break;;
        No\ \(install\ later\) ) INSTALL_SSL=false; break;;
    esac
done

if [ "$INSTALL_SSL" = true ]; then
    read -p "Enter your email for Let's Encrypt: " EMAIL
    read -p "Force HTTPS redirect? (y/n): " REDIRECT
fi

echo "------------------------------------------"
echo "Updating package list..."
echo "------------------------------------------"
sudo apt update && sudo apt upgrade -y

echo "------------------------------------------"
echo "Installing Nginx..."
echo "------------------------------------------"
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx

echo "------------------------------------------"
echo "Creating reverse proxy configuration..."
echo "------------------------------------------"

sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN;

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

sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

if [ "$INSTALL_SSL" = true ]; then
    echo "------------------------------------------"
    echo "Installing Certbot & requesting certificate"
    echo "------------------------------------------"
    sudo apt install certbot python3-certbot-nginx -y

    if [[ "$REDIRECT" == "y" || "$REDIRECT" == "Y" ]]; then
        sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --redirect
    else
        sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos
    fi

    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
    SSL_STATUS="SSL Installed"
else
    echo "SSL installation skipped. You can install SSL later with:"
    echo "--------------------------------------------------------"
    echo "sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
    echo "--------------------------------------------------------"
    SSL_STATUS="SSL Not Installed"
fi

echo ""
echo "=========================================="
echo " Installation Complete!"
echo " Domain: http://$DOMAIN"
echo " Proxy to: http://127.0.0.1:$PORT"
echo " SSL Status: $SSL_STATUS"
echo "=========================================="
