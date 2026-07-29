#!/bin/bash
set -euxo pipefail

# Wazuh 5.0.0 Server Installation Script
# Based on quickstart installer approach (same as 4.14.6)

${ttl_prologue}

exec > >(tee /var/log/wazuh-install.log)
exec 2>&1

echo "═════════════════════════════════════════════════════════════════"
echo "Starting Wazuh ${wazuh_version} Server Installation"
echo "TTL: ${resource_ttl_minutes} minutes"
echo "═════════════════════════════════════════════════════════════════"

# Update system
echo "[1/5] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq > /dev/null 2>&1

# Download Wazuh quickstart installer
echo "[2/5] Downloading Wazuh ${wazuh_version} quickstart installer..."
WAZUH_BRANCH="${wazuh_branch}"  # "5.0" for 5.0.x releases
INSTALL_URL="https://packages.wazuh.com/$${WAZUH_BRANCH}/wazuh-install.sh"

# Verify URL is accessible before piping to bash
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "$$INSTALL_URL")
if [ "$$HTTP_CODE" != "200" ]; then
  echo "ERROR: Wazuh installer URL returned HTTP $$HTTP_CODE"
  echo "URL: $$INSTALL_URL"
  echo "Check that WAZUH_BRANCH='$$WAZUH_BRANCH' is correct for version ${wazuh_version}"
  exit 1
fi

# Download and execute installer with -a (all-in-one) and -i (interactive) flags
curl -sO "$$INSTALL_URL"
chmod +x wazuh-install.sh

# Run installer with required flags
echo "[3/5] Running Wazuh quickstart installer (this takes ~30 minutes)..."
bash ./wazuh-install.sh -a -i

# Verify installation completed
echo "[4/5] Verifying installation..."
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  if systemctl is-active --quiet "$$s"; then
    echo "✓ $$s is active"
  else
    echo "✗ $$s is NOT active"
    systemctl status "$$s" || true
    exit 1
  fi
done

# Known issue in 4.14.6: Indexer binds to localhost only
# RESEARCH NOTE: Verify if this still exists in 5.0.0
echo "[5/5] Checking Indexer configuration..."
if grep -q 'network.host: "127.0.0.1"' /etc/wazuh-indexer/opensearch.yml 2>/dev/null; then
  echo "⚠ WARNING: Indexer is localhost-only (known 4.14.6 issue)"
  echo "Attempting to make Indexer accessible externally..."
  sed -i 's|^network.host: .*|network.host: "0.0.0.0"|' /etc/wazuh-indexer/opensearch.yml
  systemctl restart wazuh-indexer
  sleep 5
  if systemctl is-active --quiet wazuh-indexer; then
    echo "✓ Indexer restarted successfully"
  else
    echo "✗ Indexer failed to restart"
    systemctl status wazuh-indexer || true
  fi
fi

# Mark installation complete
echo "WAZUH_INSTALL_COMPLETE=$(date -Is)" > /root/WAZUH_READY
echo "WAZUH_VERSION=${wazuh_version}" >> /root/WAZUH_READY

# Final verification
echo ""
echo "═════════════════════════════════════════════════════════════════"
echo "Wazuh ${wazuh_version} Installation Complete"
echo "═════════════════════════════════════════════════════════════════"
echo ""
echo "Verify services:"
systemctl status wazuh-manager wazuh-indexer wazuh-dashboard || true

echo ""
echo "Dashboard URL: https://$(hostname -I | awk '{print $1}')"
echo ""
echo "Retrieve credentials:"
echo "  sudo tar -xOf /root/wazuh-install-files.tar \\"
echo "    wazuh-install-files/wazuh-passwords.txt"
echo ""
echo "TTL enforcement: Auto-termination in ${resource_ttl_minutes} minutes"
echo "═════════════════════════════════════════════════════════════════"
