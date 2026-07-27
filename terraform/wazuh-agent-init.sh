#!/bin/bash
set -e

echo "Starting Wazuh ${wazuh_version} Agent Installation..."
exec > >(tee /var/log/wazuh-agent-installation.log)
exec 2>&1

# Update system
apt-get update -qq
apt-get upgrade -y -qq > /dev/null 2>&1

# Install dependencies
apt-get install -y curl wget gnupg2 ca-certificates > /dev/null 2>&1

# Add Wazuh repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import - 2>&1 | grep -v "gpg:" || true
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list

# Update package lists
apt-get update -qq

# Install Wazuh Agent
echo "Installing Wazuh Agent ${wazuh_version}..."
apt-get install -y wazuh-agent=${wazuh_version}-* > /dev/null 2>&1

# Configure agent to connect to Wazuh server
echo "Configuring Wazuh Agent..."
sed -i "s/<manager_address>127.0.0.1<\/manager_address>/<manager_address>${wazuh_server_ip}<\/manager_address>/" /var/ossec/etc/ossec.conf

# Start and enable agent
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

sleep 5

echo "Wazuh Agent ${wazuh_version} Installation Complete"
echo "Manager: ${wazuh_server_ip}:1514"
