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

# Install Wazuh Agent.
# WAZUH_MANAGER is the documented way to set the manager address at install
# time - the package substitutes it into ossec.conf for us.
echo "Installing Wazuh Agent ${wazuh_version}..."
WAZUH_MANAGER="${wazuh_server_ip}" apt-get install -y wazuh-agent=${wazuh_version}-* > /dev/null 2>&1

# Belt-and-braces: if the placeholder survived, replace it explicitly.
# The element is <address>MANAGER_IP</address> - NOT <manager_address>, which
# does not exist in Wazuh 4.x agent configs. Targeting the wrong element makes
# sed match nothing silently, leaving the literal placeholder and causing
# "ERROR: (4112): Invalid server address found: 'MANAGER_IP'".
echo "Configuring Wazuh Agent..."
sed -i "s|<address>MANAGER_IP</address>|<address>${wazuh_server_ip}</address>|" /var/ossec/etc/ossec.conf
grep -m1 '<address>' /var/ossec/etc/ossec.conf

# Start and enable agent
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

sleep 5

echo "Wazuh Agent ${wazuh_version} Installation Complete"
echo "Manager: ${wazuh_server_ip}:1514"
echo "WAZUH_AGENT_READY=$(date -Is)" > /root/WAZUH_AGENT_READY
