---
name: wazuh-indexer-cluster
description: Stand up a real multi-node Wazuh 5.0 indexer cluster on AWS for documentation testing — topology terraform, an in-place opensearch.yml editor, and the traps that cost time on every previous pass. Use when testing the "Wazuh indexer cluster" document or any procedure that needs more than one indexer node.
---

# Wazuh indexer cluster test rig

Seven passes of the "Wazuh indexer cluster" document have needed the same
infrastructure and hit the same traps. This is that rig, so pass eight starts
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
# 3 indexers + manager + dashboard + 2 AIO
terraform plan -out=tfplan && terraform apply tfplan

# add a node — the plan must say "1 to add, 0 to change"
terraform plan -var="cluster_indexer_count=4" -out=tfplan4 && terraform apply tfplan4
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

## Reading the document (three exports, not two)

Pull **all three** Drive exports. They disagree, and each one is the only source
for something:

```
read_file_content                               -> markdown   (flattens table-cell code blocks)
download_file_content exportMimeType=text/plain -> newlines + comment threads
download_file_content exportMimeType=text/html  -> heading ids, bookmarks, NBSP
```

- The **plain-text** export arrives **base64-encoded** in `content` — decode it,
  then strip CRLF. Markdown arrives as plain text in `fileContent`.
- Markdown and plain text can differ when a suggested edit is unaccepted. Diff
  them before reporting, or you review the wrong text.
- Only the **HTML** export keeps `<h_ id="h.xxxx">` heading ids and `id.xxxx`
  bookmark anchors. Cross-check every `#heading=`/`#bookmark=` link in the
  markdown against the ids defined in the HTML — pass 6 found four dead links
  that way, including the only route to the deployment script.
- Only the HTML export preserves NBSP; the other two normalise it to a space. So
  "0 NBSP" from markdown/plain text does **not** mean the doc is clean.

Extract a script with `sed -n 'A,Bp'` and **check the last line is there** — an
off-by-one drops the closing `fi` and you misreport a syntax error. This has now
bitten two passes running.

## Terraform, under the permission classifier

`terraform apply -auto-approve` is refused as **"Blind Apply."** Use
`terraform plan -out=tfplan` (read the summary, confirm `N to add, 0 to change`)
then `terraform apply tfplan`. `init` and `apply` both need
`dangerouslyDisableSandbox` — the registry and the AWS endpoints are otherwise
unreachable.

## Installing the all-in-one precondition

The assistant still 403s on its default artifact URL
(`packages.wazuh.com/production/5.x/artifact-urls/artifact_urls_5.0.0.yaml`,
exit 22). `-a -i` is invalid — `-i` is not a flag. What works:

```bash
sudo bash wazuh-install-5.0.0-beta5.sh -a -id -d pre-release
```

## The heap is not optional

A doc-built cluster runs `-Xms1g/-Xmx1g` whatever the host size, and stock
`opensearch.yml` sets `indices.breaker.total.limit: 80%`. At 1 GB that is an
819 MB breaker, and **shard recovery cannot complete**: stop and start one node
and the cluster goes red with shards stuck `INITIALIZING` forever
(`CircuitBreakingException [parent] Data too large`). Set the heap to ~half of
RAM on every node *before* judging any resilience behaviour, or you will
attribute a tuning failure to the procedure under test.

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

## Traps found on pass 6

- **The doc's own tuning step breaks startup.** `bootstrap.memory_lock: true` is
  already in the shipped `opensearch.yml`; adding it as the doc says gives
  `JsonParseException: Duplicate field` and the service will not start. Expect
  it, prove it, then delete the duplicate line to get a cluster. Same story for
  `LimitMEMLOCK=infinity`, already at line 57 of the packaged unit.
- **Only the `wazuh` AWS profile has valid credentials** here. `default` and
  `security` return `InvalidClientTokenId`, which looks like an expired session
  rather than a wrong profile.
- **The MCP/Playwright browser cannot open the dashboard** —
  `ERR_CERT_AUTHORITY_INVALID`, no ignore-cert option. Verify Dev Tools
  functionally instead: `POST /auth/login` for a session cookie, then
  `POST /api/console/proxy?path=<path>&method=GET` with an `osd-xsrf` header.
  That is the same endpoint the Dev Tools console itself calls.
- **Installer filenames lie about the version.** `wazuh-install-5.0.0-beta5.sh`
  downloads `wazuh-manager_5.0.0-beta5_amd64.deb`, but `dpkg -l` reports
  `5.0.0-1` — the same build the apt repo serves. No skew; do not chase it.
- **Judge a doc's shard/drain instructions against `_cat/shards` with no
  filter.** `wazuh-*` matches only 26–36 of the 66 shards on a node; the rest are
  `.opensearch-sap-*` and friends, 21 of which ship with **zero replicas**. This
  is also why losing one node of three turns the cluster red.

## Traps found on pass 7

- **The Markdown export can drop a whole section.** Pass 7's *Removing a Wazuh
  indexer node* — heading, six steps, five tables — was **entirely absent** from
  `read_file_content`'s markdown but complete in the HTML export. The only clue
  was a Contents entry whose anchor resolved fine while no matching heading
  existed in the md. This is stronger than the known "md and plain text can
  disagree": always reconcile the **Contents list against the headings found in
  the HTML**, and extract any missing section's body from the HTML. Reporting
  "this section is empty" off the markdown would have been a false critical.
- **`.opendistro-alerting-*` cannot be modified over REST, by anyone.**
  `plugins.security.system_indices.enabled: true` plus
  `system_indices.indices` (which lists `.opendistro-alerting-config`) makes any
  settings PUT matching it return
  `security_exception ... User [name=admin, backend_roles=[admin]]`, HTTP 403 —
  admin included. A multi-pattern PUT is **atomic**, so one protected index in
  the list silently discards the whole request. Always isolate a failing
  multi-pattern request one pattern at a time before attributing the cause.
- **The installation assistant sizes the heap; the package does not.** An
  installer-built all-in-one came up `-Xms1954m/-Xmx1954m` (~25% of RAM), not
  `1g`. A sed like `s/^-Xms[0-9]*g/` silently matches nothing there — use
  `-E 's/^-Xms[0-9]+[mg]/'`. Check the value after editing, never assume.
- **Red after a node stops is not necessarily terminal.** With a correct heap,
  `delayed_unassigned_shards` equals `unassigned_shards` for the first ~60s
  (`node_left.delayed_timeout` is 1m), then recovery runs: 67% → 85% → 99.5%
  over ~90s. Poll for at least 3 minutes and report the **stable** state; a
  single reading at t+30s reports a transient as a permanent failure.
- **The distributed add-node cert collision is path-specific.** It fires on an
  existing indexer node (whose `/root/wazuh-certificates/` the main flow created)
  and *not* on the all-in-one path, where `/root` is clean. Test both before
  calling it universal.
- **Console-proxy needs the query string encoded.** `POST /api/console/proxy?
  path=_cat/allocation?v&h=node,shards` returns
  `400 [request query.h]: definition for this key is missing` — that is the
  harness, not the doc. Encode the inner `&` as `%26` and it returns 200. Re-run
  encoded before reporting any console command as broken.
- **Check the AWS key file, not chmod.** `chmod 600` on the terraform-written
  `.pem` fails "Permission denied" on the Windows working tree; copy the key into
  the scratchpad first, then chmod there.
