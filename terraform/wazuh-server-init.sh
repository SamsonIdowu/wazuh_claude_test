#!/bin/bash
# Wazuh Server Initialization Script
# Deploys Wazuh manager, indexer, and dashboard using quickstart installer
# Handles version-specific installation and known issues

${ttl_prologue}
set -euxo pipefail
exec > >(tee -a /var/log/wazuh-install.log) 2>&1

echo "Starting Wazuh Server Installation"
echo "Version: ${wazuh_version}"
echo "TTL: ${resource_ttl_minutes} minutes"

cd /root

# 5.0-beta ships from a different distribution point than stable releases:
# a per-version installer script (not the generic wazuh-install.sh) hosted on
# an internal staging domain, requiring -d pre-release. packages.wazuh.com
# returns S3 AccessDenied (403) for /5.0/wazuh-install.sh - it does not exist
# there yet. See documentation.wazuh.com/5.0-beta/quickstart.html.
if [[ "${wazuh_version}" == *beta* ]]; then
  INSTALLER="wazuh-install-${wazuh_version}.sh"
  curl -sO "https://packages-staging.xdrsiem.wazuh.info/pre-release/5.x/installation-assistant/$${INSTALLER}"
  bash "./$${INSTALLER}" -a -id -d pre-release
else
  # Extract major.minor version
  WAZUH_BRANCH="$(echo "${wazuh_version}" | cut -d. -f1,2)"
  curl -sO "https://packages.wazuh.com/$${WAZUH_BRANCH}/wazuh-install.sh"
  bash ./wazuh-install.sh -a -i
fi

# Known issue: Quickstart installer binds indexer to localhost (127.0.0.1)
# This prevents dashboard and external connections even with security group open
# Workaround: Rebind to 0.0.0.0 and restart
echo "Fixing indexer network binding..."
sed -i 's|^network.host: .*|network.host: "0.0.0.0"|' /etc/wazuh-indexer/opensearch.yml
systemctl restart wazuh-indexer

# Wait for indexer to be active
for i in $(seq 1 12); do
  if systemctl is-active --quiet wazuh-indexer; then
    echo "Indexer is active"
    break
  fi
  sleep 5
done

# Extract and persist credentials for retrieval
tar -xf wazuh-install-files.tar -C /root 2>/dev/null || true
echo "WAZUH_INSTALL_COMPLETE=$(date -Is)" > /root/WAZUH_READY
echo "WAZUH_VERSION=${wazuh_version}" >> /root/WAZUH_READY

echo "Wazuh Server Installation Complete"
