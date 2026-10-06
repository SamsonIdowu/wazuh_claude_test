#!/bin/bash
# --- TTL self-termination (${ttl} min), scheduled first so any later failure still terminates ---
/sbin/shutdown -h +${ttl} "awsrc1 TTL ${ttl}min" || true
echo "TTL_SCHEDULED=$(date -Is) MINUTES=${ttl}" > /root/TTL_SCHEDULED
exec > /var/log/rc1-init.log 2>&1
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3-pip curl jq unzip

mkdir -p /root/rc1 && cd /root/rc1
echo '${yaml_b64}' | base64 -d > artifact_urls.yaml
INST=$(grep '^wazuh_installation_assistant:' artifact_urls.yaml | cut -d'"' -f2)
AGENT=$(grep '^wazuh_agent_amd64_deb:' artifact_urls.yaml | cut -d'"' -f2)
code=$(curl -s -o wazuh-install.sh -w '%%{http_code}' "$INST"); echo "installer http=$code"
[ "$code" = "200" ] || exit 1
bash wazuh-install.sh -a -id -d local > /root/rc1/wazuh-install.log 2>&1
echo "install exit=$?"

# Root-only wrappers. They read the generated credentials themselves, so no
# password ever has to appear on a command line or in a tool result.
cat > /usr/local/sbin/idx <<'EOS'
#!/bin/bash
# usage: idx METHOD PATH [curl args...]   (indexer, port 9200, admin)
P=$(grep '^WAZUH_INDEXER_ADMIN_PASSWORD=' /etc/wazuh/credentials.env | cut -d= -f2- | sed "s/^[\"']//; s/[\"']$//")
m=$1; shift; p=$1; shift
exec curl -sk -u "admin:$P" -X "$m" "https://localhost:9200$p" -H 'Content-Type: application/json' "$@"
EOS
cat > /usr/local/sbin/dash <<'EOS'
#!/bin/bash
# usage: dash METHOD PATH [curl args...]  (dashboard, port 443, admin)
P=$(grep '^WAZUH_INDEXER_ADMIN_PASSWORD=' /etc/wazuh/credentials.env | cut -d= -f2- | sed "s/^[\"']//; s/[\"']$//")
m=$1; shift; p=$1; shift
exec curl -sk -u "admin:$P" -X "$m" "https://localhost:443$p" -H 'Content-Type: application/json' -H 'osd-xsrf: true' "$@"
EOS
cat > /usr/local/sbin/wapi <<'EOS'
#!/bin/bash
# usage: wapi METHOD PATH [curl args...]  (manager API, port 55000, wazuh-wui)
P=$(grep '^WAZUH_MANAGER_WUI_PASSWORD=' /etc/wazuh/credentials.env | cut -d= -f2- | sed "s/^[\"']//; s/[\"']$//")
T=$(curl -sk -u "wazuh-wui:$P" -X POST 'https://localhost:55000/security/user/authenticate?raw=true')
m=$1; shift; p=$1; shift
exec curl -sk -H "Authorization: Bearer $T" -X "$m" "https://localhost:55000$p" -H 'Content-Type: application/json' "$@"
EOS
chmod 700 /usr/local/sbin/idx /usr/local/sbin/dash /usr/local/sbin/wapi

# Agent on the manager host: 5.0 manager ships no wodles/aws, the agent does.
code=$(curl -s -o /root/rc1/agent.deb -w '%%{http_code}' "$AGENT"); echo "agent http=$code"
WAZUH_MANAGER=127.0.0.1 WAZUH_AGENT_NAME=rc1-aws-collector dpkg -i /root/rc1/agent.deb
sed -i 's|MANAGER_IP|127.0.0.1|g' /var/ossec/etc/ossec.conf
# Enrol through the API rather than authd (authd.pass is regenerated on every manager start).
for i in $(seq 1 30); do
  KEY=$(/usr/local/sbin/wapi POST '/agents/insert/quick?agent_name=rc1-aws-collector' | jq -r '.data.key // empty')
  [ -n "$KEY" ] && break; sleep 10
done
if [ -n "$KEY" ]; then echo "$KEY" | base64 -d > /var/ossec/etc/client.keys; chown root:wazuh /var/ossec/etc/client.keys; chmod 640 /var/ossec/etc/client.keys; echo enrolled; fi
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl restart wazuh-agent

pip3 install --break-system-packages boto3==1.34.135 pyarrow==14.0.1 numpy==1.26.0
mkdir -p /root/.aws
printf '[default]\nregion = us-east-1\n' > /root/.aws/config
dpkg -l | grep -i wazuh > /root/rc1/versions.txt
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard wazuh-agent
touch /root/RC1_INIT_DONE
