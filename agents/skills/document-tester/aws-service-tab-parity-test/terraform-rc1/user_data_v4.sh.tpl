#!/bin/bash
# --- TTL self-termination (${ttl} min), scheduled first so any later failure still terminates ---
/sbin/shutdown -h +${ttl} "awsrc1 TTL ${ttl}min" || true
echo "TTL_SCHEDULED=$(date -Is) MINUTES=${ttl}" > /root/TTL_SCHEDULED
exec > /var/log/rc1-init.log 2>&1
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3-pip curl jq unzip docker.io

cd /root
code=$(curl -s -o wazuh-install.sh -w '%%{http_code}' https://packages.wazuh.com/4.14/wazuh-install.sh)
echo "installer http=$code"
[ "$code" = "200" ] || exit 1
bash wazuh-install.sh -a -i > /root/wazuh-install.log 2>&1
echo "install exit=$?"

pip3 install --break-system-packages boto3==1.34.135 pyarrow==14.0.1 numpy==1.26.0
mkdir -p /root/.aws
printf '[default]\nregion = us-east-1\n' > /root/.aws/config

# Archive every event, so events that raise no alert can still be shown as sample logs.
sed -i 's|<logall_json>no</logall_json>|<logall_json>yes</logall_json>|' /var/ossec/etc/ossec.conf
systemctl restart wazuh-manager
sleep 20
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard
touch /root/RC1_INIT_DONE
