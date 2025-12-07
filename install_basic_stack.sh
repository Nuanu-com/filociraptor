#!/bin/bash

# Auto install basic server stack
# Nginx, Docker, Docker Compose, net-tools, rsync

echo "======================================="
echo " Installing NGINX, Docker, Docker Compose, net-tools, rsync"
echo "======================================="

# Update system
sudo apt update -y && sudo apt upgrade -y

# Install general packages
sudo apt install -y nginx net-tools rsync curl ca-certificates gnupg lsb-release

# Enable and start NGINX
sudo systemctl enable nginx
sudo systemctl start nginx

echo "---- Installing Docker ----"
# Remove older Docker
sudo apt remove -y docker docker-engine docker.io containerd runc

# Setup Docker repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update -y

# Install Docker packages
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

echo "---- Installing Docker Compose (standalone) ----"
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "======================================="
echo " Installation Completed!"
echo " Versions:"
echo "---------------------------------------"
nginx -v
docker --version
docker-compose --version
echo "======================================="
echo " You may need to re-login or run: sudo usermod -aG docker \$USER"
echo "======================================="
