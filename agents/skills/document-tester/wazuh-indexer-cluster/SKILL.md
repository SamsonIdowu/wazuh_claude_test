---
name: wazuh-indexer-cluster
description: Stand up a real multi-node Wazuh 5.0 indexer cluster on AWS for documentation testing — topology terraform, an in-place opensearch.yml editor, and the traps that cost time on every previous pass. Use when testing the "Wazuh indexer cluster" document or any procedure that needs more than one indexer node.
---

# Wazuh indexer cluster test rig

Four passes of the "Wazuh indexer cluster" document have needed the same
infrastructure and hit the same traps. This is that rig, so pass five starts
from something that works.

## Files

| File | What it is |
|---|---|
| `terraform-main.tf` | Provider, default-VPC lookup, its own SSH key, TTL prologue. Rename to `main.tf`. |
| `terraform-topology.tf` | The hosts: N indexers + manager + dashboard + 2 all-in-one. Rename to `topology.tf`. |
| `terraform-variables.tf` | Region, profile, CIDRs, TTL. Rename to `variables.tf`. |
| `configure-indexer-node.py` | Sets the five cluster-identity keys in `opensearch.yml` in place, then verifies its own edit. |

Copy the three `terraform-*.tf` files into an empty directory, drop the
`terraform-` prefix, and `terraform init`. It is a **separate root** from the
repo's baseline `terraform/` on purpose — the baseline's outputs reference
`aws_instance.wazuh_server` directly, so neutralising it with `count = 0` breaks
them, and separate state means no `-target` juggling and no risk to a concurrent
test in the shared AWS account.

```bash
terraform apply -auto-approve                          # 3 indexers + manager + dashboard + 2 AIO
terraform apply -auto-approve -var="cluster_indexer_count=4"   # add a node, 1 to add / 0 to change
```

`cluster_indexer_count` is a variable specifically so the add-a-node test does
not replace indexers 1–3. Confirm with `terraform plan` before applying: it must
say **1 to add, 0 to change**. If it wants to replace everything, something
changed `user_data` — most likely `resource_ttl_minutes`, which is baked into
`user_data` and therefore replaces **every** instance in the root. Set the TTL
once, high, and leave it.

## configure-indexer-node.py

```bash
sudo python3 configure-indexer-node.py \
  --node-name indexer-1 \
  --seed-hosts 10.0.0.1,10.0.0.2,10.0.0.3 \
  --initial-managers indexer-1,indexer-2,indexer-3 \
  --nodes-dn indexer-1,indexer-2,indexer-3
```

It exists because every key it touches is either a scalar with an existing value
or a YAML block sequence whose items continue on later lines, some commented out.
Appending a second `node.name:` or `discovery.seed_hosts:` gives you a file with
duplicate top-level keys — OpenSearch does not merge them, does not warn, and
fails at startup pointing at a line nowhere near the edit. The script deletes the
old key plus its continuation lines, writes the replacement, then re-reads the
file and asserts each key parses back to what was asked, exiting non-zero if not.

## Traps that cost time on earlier passes

- **`sudo` on every read of `/etc/wazuh-indexer/`.** Without it, `grep`, `ls` and
  `cat` return empty or "Permission denied" and it looks like a setting is
  *absent* rather than unreadable. This produced a false "heap is not configured"
  and a false "TTL never applied" (that one was `/root`, mode 700).
- **`sudo chmod 400 /etc/.../certs/*`** — the glob expands as the *calling* user,
  who cannot read a 500 root-owned directory, so it silently sets nothing. Use
  `sudo sh -c 'chmod 400 .../certs/*.pem'`, and chmod the directory last.
- **The certs tool chowns `config.yml` to root.** The next edit fails with
  "Permission denied". `sudo chown $USER:$USER config.yml` first.
- **Adding a node needs `nodes_dn` on every existing node** plus a rolling
  restart. Otherwise the new node reports `active` forever and never joins; the
  reason appears only in `/var/log/wazuh-indexer/wazuh-cluster.log`, never in
  `journalctl`.
- **Never `rm -rf /var/wazuh-manager/etc/certs`** — it deletes the package's
  `remoted.pem`/`remoted-key.pem`, which nothing regenerates. `remoted` and
  `authd` then die while `systemctl is-active` still says `active`. Check
  `wazuh-manager-control status`, not systemd.
- **Regenerating certs makes a new root CA** unless you pass the old one back in:
  `wazuh-certs-tool.sh -wi /path/root-ca.pem /path/root-ca.key`. Verify with
  `openssl verify -CAfile` and a fingerprint comparison before touching a live
  cluster.

## Verification one-liners

```bash
# cluster state — the only answer that counts
curl -sk -u admin:admin "https://$IP:9200/_cluster/health?pretty" \
  | grep -E '"status"|number_of_nodes|unassigned_shards|active_shards_percent'

curl -sk -u admin:admin "https://$IP:9200/_cat/nodes?v&h=ip,name,cluster_manager"

# manager daemons — systemd lies here, this does not
sudo /var/wazuh-manager/bin/wazuh-manager-control status

# TTL actually scheduled, not just tagged
sudo cat /root/TTL_SCHEDULED && sudo shutdown --show
```

Health is **green on a single node too** — every Wazuh index carries
`index.auto_expand_replicas: "0-1"`, so one node resolves to 0 replicas. Yellow
on a single node is a real problem, not the expected state.
