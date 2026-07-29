# Deployment Runbook — What Actually Works

Hard-won procedure for standing up Wazuh 4.14.6 + TheHive 5 on AWS. Every item
below was a real failure that cost a redeploy cycle. Read before changing the
Terraform or the init scripts.

---

## 1. Wazuh server — use the official quickstart installer

**Do this:**

```bash
WAZUH_BRANCH=4.14                      # MAJOR.MINOR, derived from 4.14.6
curl -sO "https://packages.wazuh.com/${WAZUH_BRANCH}/wazuh-install.sh"
bash ./wazuh-install.sh -a -i
```

Implemented in `terraform/main.tf` → `aws_instance.wazuh_server.user_data`.

### Why — the hand-rolled install produced an unstartable Indexer

A custom step-by-step install left `wazuh-indexer` dead on arrival:

```
org.opensearch.security.ssl.config.SslCertificatesLoader.loadConfiguration
wazuh-indexer.service: Main process exited, code=exited, status=1/FAILURE
```

Certificate regeneration, `systemctl restart`, and a full instance reboot **all
failed**. The dashboard silently appears broken because it cannot serve data
without the Indexer — the visible symptom is "cannot log in to the dashboard",
which sends you debugging the wrong component. Do not try to repair this; the
quickstart installer generates a consistent certificate set and works.

### Pitfalls

- **`-a` is mandatory.** Without it the script installs nothing.
- **Verify the URL before trusting it.** `packages.wazuh.com/4.x/wazuh-install-4.14.6.sh`
  returns **HTTP 403**. Piped to `bash` that fails *silently* and looks like a
  successful run with no Wazuh present. The valid form is
  `packages.wazuh.com/<MAJOR.MINOR>/wazuh-install.sh`.
- **Takes ~30 minutes**, not 10. Gate on a marker file, not a guess:
  ```bash
  set -euxo pipefail
  exec > >(tee -a /var/log/wazuh-install.log) 2>&1
  # ... install ...
  echo "WAZUH_INSTALL_COMPLETE=$(date -Is)" > /root/WAZUH_READY
  ```
  Then poll for `/root/WAZUH_READY` and confirm `cloud-init status` is `done`.

### Retrieving credentials

The installer generates **random** passwords — it is *not* `admin/admin`:

```bash
sudo tar -xOf /root/wazuh-install-files.tar \
  wazuh-install-files/wazuh-passwords.txt
```

Yields two distinct accounts:
- `admin` → dashboard + indexer
- `wazuh-wui` → API on `:55000`

### Indexer binds to localhost only — confirmed recurring, not a fluke

The quickstart installer sets `network.host: "127.0.0.1"` in
`/etc/wazuh-indexer/opensearch.yml`. If the indexer needs to be reachable
externally (e.g. for Shuffle Cloud, or any client outside the VPC), opening
port 9200 in the security group is **not enough** — this happened identically
on two separate deployments. Fix and confirm it comes back up before trusting
it:

```bash
sudo sed -i 's|^network.host: .*|network.host: "0.0.0.0"|' \
  /etc/wazuh-indexer/opensearch.yml
sudo systemctl restart wazuh-indexer
sudo systemctl is-active wazuh-indexer   # wait for "active", don't assume
```

This is now applied automatically in `terraform/main.tf`'s `wazuh_server`
`user_data`, immediately after `wazuh-install.sh` runs and before the
`WAZUH_READY` marker is written — so a fresh deploy shouldn't need this
manual step again. If it recurs a third time, the fix belongs upstream in the
installer's defaults, not in this repo's workaround.

### Verify (do not assume)

```bash
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  systemctl is-active $s; done          # expect: active ×3
curl -k -o /dev/null -w '%{http_code}\n' https://<SERVER_IP>   # expect: 302
curl -k -u 'wazuh-wui:<PW>' -X POST \
  https://<SERVER_IP>:55000/security/user/authenticate          # expect: JWT
```

---

## 2. Wazuh agent — two independent bugs

### 2a. The config placeholder is `<address>MANAGER_IP</address>`

Wazuh 4.x agent config uses:

```xml
<server>
  <address>MANAGER_IP</address>
```

There is **no `<manager_address>` element**. A `sed` targeting
`<manager_address>127.0.0.1</manager_address>` matches nothing, silently leaves
the literal placeholder, and the agent dies with:

```
wazuh-agentd: ERROR: (4112): Invalid server address found: 'MANAGER_IP'
wazuh-agentd: ERROR: (1215): No client configured. Exiting.
```

Preferred fix — let the package substitute it at install time:

```bash
WAZUH_MANAGER="<MANAGER_PRIVATE_IP>" apt-get install -y wazuh-agent=4.14.6-*
```

Belt-and-braces, then assert:

```bash
sed -i "s|<address>MANAGER_IP</address>|<address>${IP}</address>|" \
  /var/ossec/etc/ossec.conf
grep -m1 '<address>' /var/ossec/etc/ossec.conf
```

### 2b. Enrollment needs port **1515**, not just 1514

With only 1514 open the agent starts cleanly and logs:

```
wazuh-agentd: INFO: Requesting a key from server: 172.31.1.154
```

…then stalls forever. Registration (authd) is a **separate port, 1515**. Symptom
is subtle: the service is `active` and the log shows no error, but
`agent_control -l` never lists the agent.

Both ports are VPC-internal only — the agent reaches the manager over **private
IPs**, so these must not be world-open:

```hcl
ingress {                                     # 1514 tcp+udp, and 1515 tcp
  from_port   = 1515
  to_port     = 1515
  protocol    = "tcp"
  cidr_blocks = [data.aws_vpc.default.cidr_block]   # NOT 0.0.0.0/0
}
```

Only 22 / 443 / 55000 are public.

### Verify

```bash
# On the manager — the agent must appear as a second entry:
sudo /var/ossec/bin/agent_control -l
#   ID: 000, Name: ip-172-31-1-154 (server), IP: 127.0.0.1, Active/Local
#   ID: 001, Name: ip-172-31-6-153,          IP: any,       Active   <-- this
```

`systemctl is-active wazuh-agent` alone is **not** proof of enrollment.

---

## 3. TheHive 5 — use StrangeBee's official compose, not a hand-written one

Clone upstream rather than authoring a compose file:

```bash
git clone --depth 1 https://github.com/StrangeBeeCorp/docker.git
cd docker/testing        # 'testing' profile = single node, for prototyping
```

Implemented in `terraform/thehive-init.sh`.

### Why — four failures from hand-rolling it

1. **`strangebee/thehive:latest` does not exist.** There is no `latest` tag; real
   tags are `5.7`, `5.7.3`, `5.7.4`, `5`. The pull failure aborts cloud-init and
   nothing starts:
   ```
   failed to resolve reference "docker.io/strangebee/thehive:latest": not found
   ```
2. **TheHive 5 needs three services**, not two: **Cassandra** (database) +
   **Elasticsearch** (index) + file storage. Pairing it with Elasticsearch alone
   cannot work.
3. **The flag is `--secret`, not `--secret-key`.** The latter is rejected with
   `Unknown parameter '--secret-key', exiting` and the container crash-loops
   while dumping its usage text. Upstream avoids CLI flags entirely, using
   `--no-config --no-config-secret` plus a mounted `application.conf`.
4. **Named volumes are root-owned; TheHive runs as uid 1000** →
   `ERROR the directory '/data/files' is not writable`. Upstream sidesteps this
   with bind mounts owned by the invoking user.

### Non-obvious setup requirements

- **`vm.max_map_count`** — Elasticsearch will not start without it:
  ```bash
  sysctl -w vm.max_map_count=262144
  echo "vm.max_map_count=262144" > /etc/sysctl.d/99-elasticsearch.conf
  ```
- **Clone and init as uid 1000 (`ubuntu`).** Upstream's compose runs every
  container as `${UID}:${GID}` over bind mounts; root-owned directories break it.
- **`init.sh` has TWO interactive prompts, not one.** It calls
  `check_permissions.sh` *first*, which asks `Fix permissions? (y/n)`. A single
  newline answers "no" → `exit 1` → `init.sh` aborts → **no `.env` is written** →
  compose resolves every image tag to blank:
  ```
  unable to get image 'elasticsearch:': invalid reference format
  ```
  A `git clone` does not reproduce upstream's expected modes, so set them
  deterministically and the prompt never appears:
  ```bash
  find ./cassandra ./certificates ./elasticsearch ./nginx ./scripts ./thehive \
       -type d -exec chmod 750 {} +
  find ./cortex -type d -exec chmod 755 {} +
  find ./docker-compose.yml ./dot.env.template ./cassandra ./certificates \
       ./cortex ./elasticsearch ./nginx ./thehive -type f -exec chmod 644 {} +
  find ./scripts -type f -exec chmod 755 {} +
  bash ./scripts/check_permissions.sh     # must exit 0
  printf '\n' | bash ./scripts/init.sh    # only the hostname prompt remains
  test -s .env                            # assert, don't hope
  ```
- **Start dependencies first, then TheHive.** `docker compose up -d ... thehive`
  aborts with `dependency failed to start: container elasticsearch is unhealthy`
  because Elasticsearch needs ~2 minutes to go healthy and `up` will not wait
  that long. Bring up `cassandra elasticsearch`, wait for healthy, *then*
  `thehive`.
- **Skip `cortex` and `nginx`.** Each service is capped at 2G; cortex+nginx
  over-commit an 8G host. Cortex is not needed, and TheHive publishes `:9000`
  directly so the nginx TLS proxy is redundant.
- **Sizing:** `t3.large` (8 GB) minimum. Three JVM heaps (Cassandra 1G +
  Elasticsearch 1G + TheHive 1280M) do not fit in `t3.medium`'s 4 GB.

### Access

```
URL:      http://<IP>:9000/thehive        <-- note the /thehive context path
Login:    admin@thehive.local / secret    <-- NOT admin/admin
Status:   http://<IP>:9000/thehive/api/status   -> 200 + version JSON
```

---

## 4. Terraform gotcha that wasted a full cycle

**Editing `user_data` does not re-provision an instance.**
`user_data_replace_on_change = false` (the default here), and cloud-init only
runs user-data on **first boot**. A `terraform apply` after editing the script
performs a stop/start resize, keeps the **same instance ID**, and the corrected
script never executes — while the apply reports success.

Tell-tale signs: instance ID unchanged, new log file absent, old content still
in on-disk config.

Force a genuine replacement:

```bash
terraform apply -replace=aws_instance.thehive -target=aws_instance.thehive
```

Confirm the **instance ID changed**. Also note each replacement assigns a new
public IP.

---

## 4b. The TTL was cosmetic — cost $4.92

`resource_ttl_minutes` and `enable_auto_termination` originally produced **only**:

1. `TTL_AND_EXTENSION.txt`, a local text file asserting auto-termination
2. EC2 tags `TTL_Minutes` / `AutoTermination` — inert metadata nothing reads

No Lambda, no CloudWatch alarm, no scheduled shutdown. Terraform *outputs* said
`auto_termination_enabled = true`, and `test/TTL_AND_AUTO_TERMINATION.md` stated
resources "will be automatically terminated to prevent unexpected costs". Both
described an intention no code implemented. Three instances ran **17 hours**
(~$4.92) past a 240-minute TTL.

**Now enforced** in `main.tf` via `locals.ttl_prologue`:

```bash
#!/bin/bash
/sbin/shutdown -h +${resource_ttl_minutes} || true      # FIRST action in user_data
echo "TTL_SCHEDULED=$(date -Is)" > /root/TTL_SCHEDULED
```

plus, on every instance:

```hcl
instance_initiated_shutdown_behavior = "terminate"
```

Both halves matter:

- Scheduling **first**, before any install work, means a hung or failed install
  still terminates. Appended at the end, a failure leaves the box running forever.
- Without `= "terminate"` the instance merely **stops**, and its EBS volumes keep
  billing.

Verify it was scheduled — do not assume:

```bash
ssh ... "sudo cat /root/TTL_SCHEDULED; shutdown --show"
```

Note `user_data` runs only on first boot, so raising `resource_ttl_minutes` does
**not** reschedule a running instance. Use `sudo shutdown -c && sudo shutdown -h +N`
on the box.

**General lesson:** a tag, a variable name, or a line of documentation is not a
mechanism. Before trusting any safety property, find the code that enforces it.

---

## 5. Verification checklist — never report success without these

| Check | Command | Expected |
|---|---|---|
| Wazuh services | `systemctl is-active wazuh-{manager,indexer,dashboard}` | `active` ×3 |
| Dashboard | `curl -k -o /dev/null -w '%{http_code}' https://<IP>` | `302` |
| Wazuh API | `POST /security/user/authenticate` | JWT returned |
| Agent enrolled | `agent_control -l` on manager | agent listed as ID 001+ |
| TheHive | `curl <IP>:9000/thehive/api/status` | `200` + version JSON |
| cloud-init | `cloud-init status` | `done` (not `error`) |

`systemctl is-active` on the agent proves the process runs, **not** that it
enrolled. `docker ps` showing `Up` proves the container started, **not** that the
app serves traffic. Check the endpoint.

---

## Known cosmetic issue

Cassandra's healthcheck (`cqlsh -u cassandra -p cassandra`) may report
`unhealthy` after TheHive connects, while TheHive itself stays healthy and
serving. TheHive's own healthcheck passing is the meaningful signal, since it
proves Cassandra connectivity.
