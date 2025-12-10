#!/bin/bash

echo "=============================================="
echo "      LET'S ENCRYPT SSL INSTALLER (NGINX)"
echo "=============================================="
echo ""

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "❌ Nginx is not installed. Please install Nginx first."
    exit 1
fi

# Inputs
read -p "Enter your domain name (example: mydomain.com): " DOMAIN
read -p "Enter your email for Let's Encrypt (example: admin@mydomain.com): " EMAIL
read -p "Force HTTPS redirect? (y/n): " REDIRECT

echo ""
echo "----------------------------------------------"
echo " Installing Certbot & plugin for Nginx"
echo "----------------------------------------------"
sudo apt update
sudo apt install certbot python3-certbot-nginx -y

echo "----------------------------------------------"
echo " Requesting Let's Encrypt SSL certificate"
echo "----------------------------------------------"

if [[ "$REDIRECT" == "y" || "$REDIRECT" == "Y" ]]; then
    sudo certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --redirect
else
    sudo certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos
fi

echo ""
echo "----------------------------------------------"
echo " Enabling SSL auto-renew service"
echo "----------------------------------------------"
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

echo ""
echo "=============================================="
echo "        SSL SETUP COMPLETED SUCCESSFULLY"
echo "=============================================="
echo " Domain      : https://$DOMAIN"
echo " Email       : $EMAIL"
echo " Redirect    : $REDIRECT"
echo " Auto Renew  : Enabled"
echo "=============================================="
