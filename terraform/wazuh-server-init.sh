#!/bin/bash
set -e

echo "Starting Wazuh ${wazuh_version} Server Installation..."
exec > >(tee /var/log/wazuh-installation.log)
exec 2>&1

# Update system
apt-get update -qq
apt-get upgrade -y -qq

# Install dependencies
apt-get install -y curl wget gnupg2 lsb-release ca-certificates > /dev/null 2>&1

# Add Wazuh repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import - 2>&1 | grep -v "gpg:" || true
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list

# Update package lists
apt-get update -qq

# Install Wazuh Manager
echo "Installing Wazuh Manager ${wazuh_version}..."
apt-get install -y wazuh-manager=${wazuh_version}-* > /dev/null 2>&1

# Install Wazuh Indexer
echo "Installing Wazuh Indexer ${wazuh_version}..."
apt-get install -y wazuh-indexer=${wazuh_version}-* > /dev/null 2>&1

# Install Wazuh Dashboard
echo "Installing Wazuh Dashboard ${wazuh_version}..."
apt-get install -y wazuh-dashboard=${wazuh_version}-* > /dev/null 2>&1

# Start and enable services
echo "Starting Wazuh services..."
systemctl daemon-reload

# Wazuh Manager
systemctl enable wazuh-manager
systemctl start wazuh-manager

# Wazuh Indexer - configure kernel parameters first
sysctl -w vm.max_map_count=262144
sysctl -w fs.file-max=65535
systemctl enable wazuh-indexer
systemctl start wazuh-indexer || true

# Wazuh Dashboard
systemctl enable wazuh-dashboard
systemctl start wazuh-dashboard

# Wait for services to start
sleep 15

echo "Wazuh ${wazuh_version} Server Installation Complete"
echo "Dashboard: https://$(hostname -I | awk '{print $1}')"
echo "API: https://$(hostname -I | awk '{print $1}'):55000"
