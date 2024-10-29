#!/bin/bash

# Prompt for user inputs
read -p "Enter username for Chromium: " CUSTOM_USER
read -s -p "Enter password for Chromium: " PASSWORD
echo
read -p "Enter timezone (e.g., Europe/London): " TZ
read -p "Enter main page URL for Chromium: " CHROME_CLI
read -p "Enter the first port (default 3010): " PORT1
PORT1=${PORT1:-3010}
read -p "Enter the second port (default 3011): " PORT2
PORT2=${PORT2:-3011}

# Get a list of server IPs
echo "Enter server IPs, separated by spaces:"
read -a SERVER_IPS

# Loop through each server IP
for ip in "${SERVER_IPS[@]}"; do
    echo "Connecting to server $ip and starting Chromium setup..."

    # Connect via SSH and execute the setup commands
    ssh "root@$ip" bash <<EOF
        # Update and upgrade system packages
        sudo apt update -y && sudo apt upgrade -y

        # Remove conflicting packages if they exist
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
            sudo apt-get remove -y \$pkg
        done

        # Install Docker dependencies and setup Docker repository
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Add Docker's official repository
        echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo "\$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker and Docker Compose plugin
        sudo apt update -y && sudo apt upgrade -y
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Check Docker installation
        docker --version

        # Create chromium directory and docker-compose.yaml file
        mkdir -p ~/chromium
        cat > ~/chromium/docker-compose.yaml <<EOL
---
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined #optional
    environment:
      - CUSTOM_USER=$CUSTOM_USER
      - PASSWORD=$PASSWORD
      - PUID=1000
      - PGID=1000
      - TZ=$TZ
      - CHROME_CLI=$CHROME_CLI
    volumes:
      - /root/chromium/config:/config
    ports:
      - $PORT1:3000
      - $PORT2:3001
    shm_size: '1gb'
    restart: unless-stopped
EOL

        # Run Docker Compose to start Chromium
        cd ~/chromium && docker compose up -d
EOF

    # Print completion message for the current server
    echo "Chromium setup completed on server $ip."
    echo "-------------------------------------------"
done
