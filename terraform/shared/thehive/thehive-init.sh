#!/bin/bash
# TheHive 5 via StrangeBee's OFFICIAL docker compose (testing profile)
#   repo:  https://github.com/StrangeBeeCorp/docker  (testing/)
#   docs:  https://docs.strangebee.com/thehive/installation/docker/
#
# Rationale for using upstream's files rather than a hand-written compose:
# upstream drives TheHive from a mounted application.conf (--no-config
# --no-config-secret) instead of CLI flags, pins Cassandra/Elasticsearch/TheHive
# versions in versions.env, and runs every container as ${UID}:${GID} over bind
# mounts. Hand-rolling those pieces produced a crash-looping container.
#
# Read via file() NOT templatefile() - shell ${VAR} must survive Terraform.

set -euxo pipefail
exec > >(tee -a /var/log/thehive-install.log) 2>&1

REPO_DIR=/home/ubuntu/thehive-docker
PROFILE_DIR="$REPO_DIR/testing"

echo "[*] Installing Docker and git..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y ca-certificates curl gnupg git
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

# Elasticsearch refuses to start without an elevated mmap count.
echo "[*] Tuning vm.max_map_count..."
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" > /etc/sysctl.d/99-elasticsearch.conf

# Clone and initialise AS ubuntu (uid 1000), because upstream's compose runs
# containers as ${UID}:${GID} against bind mounts - the directories must be
# owned by that same uid or the containers cannot write.
echo "[*] Cloning StrangeBee docker repo as ubuntu..."
sudo -u ubuntu -H git clone --depth 1 \
  https://github.com/StrangeBeeCorp/docker.git "$REPO_DIR"

# init.sh first calls check_permissions.sh, which exits 1 unless the tree has
# upstream's exact modes (dirs 750, cortex dirs 755, files 644, scripts 755).
# A git clone does not reproduce those, and its "Fix permissions? (y/n)" prompt
# would otherwise consume our stdin and abort with "No changes made".
# Set the modes deterministically so the check passes silently, leaving only
# init.sh's hostname prompt to answer.
echo "[*] Normalising permissions to upstream expectations..."
sudo -u ubuntu -H bash -c "cd '$PROFILE_DIR' && \
  find ./cassandra ./certificates ./elasticsearch ./nginx ./scripts ./thehive \
       -type d -exec chmod 750 {} + && \
  find ./cortex -type d -exec chmod 755 {} + && \
  find ./docker-compose.yml ./dot.env.template ./cassandra ./certificates \
       ./cortex ./elasticsearch ./nginx ./thehive -type f -exec chmod 644 {} + && \
  find ./scripts -type f -exec chmod 755 {} +"

echo "[*] Verifying permissions check passes before init..."
sudo -u ubuntu -H bash -c "cd '$PROFILE_DIR' && bash ./scripts/check_permissions.sh"

# Remaining prompt is the hostname; empty input accepts the default.
echo "[*] Running upstream init.sh (non-interactive)..."
sudo -u ubuntu -H bash -c "cd '$PROFILE_DIR' && printf '\n' | bash ./scripts/init.sh"

# init.sh must have produced .env, or compose will resolve image tags to blanks
# and fail with "invalid reference format".
if ! sudo -u ubuntu test -s "$PROFILE_DIR/.env"; then
  echo "[!] init.sh did not produce .env - aborting"
  exit 1
fi

echo "[*] Generated .env (secrets redacted):"
sudo -u ubuntu sed -E "s/(password.*=).*/\1 <redacted>/I" "$PROFILE_DIR/.env" || true

# Only cassandra + elasticsearch + thehive. Cortex and nginx are deliberately
# omitted: the compose file caps each service at 2G, and cortex+nginx on top
# would over-commit this 8G host. Cortex is not needed for this test, and
# TheHive publishes 9000 directly so the nginx TLS proxy is unnecessary.
echo "[*] Starting cassandra, elasticsearch, thehive..."
cd "$PROFILE_DIR"
docker compose up -d cassandra elasticsearch thehive

# Upstream's own healthcheck endpoint. Note the /thehive context path.
echo "[*] Waiting for TheHive API status endpoint..."
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 \
    http://localhost:9000/thehive/api/status || true)
  if [ "$code" = "200" ]; then
    echo "THEHIVE_READY=$(date -Is) HTTP=$code" > /root/THEHIVE_READY
    echo "[*] TheHive ready after $i attempts"
    break
  fi
  echo "  attempt $i: HTTP '$code' - not ready"
  sleep 15
done

if [ ! -f /root/THEHIVE_READY ]; then
  echo "[!] TheHive did NOT become ready within timeout"
  docker compose ps
  docker compose logs --tail=60 thehive || true
  exit 1
fi

echo "[*] Done. URL http://<public-ip>:9000/thehive"
echo "[*] Default login: admin@thehive.local / secret"
docker compose ps
