#!/usr/bin/env python3
"""
Set the cluster-identity keys in /etc/wazuh-indexer/opensearch.yml, in place.

Why this exists rather than `cat >>` or a few sed lines: every key this touches
is either a scalar that already has a value or a YAML *block sequence* whose
items continue on following lines, sometimes commented out. Appending a second
`node.name:` or a second `discovery.seed_hosts:` produces a file with duplicate
top-level keys. OpenSearch does not merge those and does not warn — it fails at
startup with a parse error that names a line number nowhere near the real edit,
which is a genuinely slow thing to debug on three nodes at once.

So: delete the existing key and all of its continuation lines (list items and
commented-out list items), then write the replacement at the same spot. Keys not
named on the command line are left exactly as they were, comments and all.

Usage:
  configure-indexer-node.py --file /etc/wazuh-indexer/opensearch.yml \
      --node-name indexer-1 \
      --seed-hosts 10.0.0.1,10.0.0.2,10.0.0.3 \
      --initial-managers indexer-1,indexer-2,indexer-3 \
      --nodes-dn indexer-1,indexer-2,indexer-3 \
      [--network-host 0.0.0.0] [--dry-run]

Verifies its own result: re-reads the file, asserts each requested key parses
back to the requested value, and exits non-zero if not. Per R1, a config edit
that isn't read back isn't a verified config edit.
"""

import argparse
import re
import shutil
import sys
import time

# The DN template the certs tool bakes into every node certificate. nodes_dn
# entries must match the certificate CN exactly or the node is refused at the
# transport layer with an error that reads like a generic TLS failure.
DN_TEMPLATE = 'CN={name},OU=Wazuh,O=Wazuh,L=California,C=US'


def split_key_block(lines, key):
    """Return (start, end) covering `key:` and its continuation lines.

    A continuation is any line that is indented, or is a top-level list item
    (`- x`), or is a commented-out list item (`#- x` / `# - x`). That last form
    is what the shipped file uses for the node-2 / node-3 placeholders, and
    leaving those behind is how you end up with a stale `#- "CN=node-2,..."`
    sitting under a freshly written nodes_dn block.
    """
    start = None
    for i, line in enumerate(lines):
        if re.match(r'^\s*' + re.escape(key) + r'\s*:', line):
            start = i
            break
    if start is None:
        return None, None

    end = start + 1
    while end < len(lines):
        line = lines[end]
        if line.strip() == '':
            break
        if re.match(r'^\s+\S', line):            # indented continuation
            end += 1
            continue
        if re.match(r'^-\s', line):              # top-level list item
            end += 1
            continue
        if re.match(r'^\s*#\s*-\s', line):       # commented-out list item
            end += 1
            continue
        break
    return start, end


def replace_key(lines, key, new_lines):
    start, end = split_key_block(lines, key)
    if start is None:
        # Key absent entirely (e.g. discovery.seed_hosts ships commented out
        # under a different spelling) — append rather than silently skip.
        return lines + new_lines
    return lines[:start] + new_lines + lines[end:]


def scalar(key, value):
    return ['{}: "{}"'.format(key, value)]


def seq(key, values):
    return ['{}:'.format(key)] + ['- "{}"'.format(v) for v in values]


def read_back(path):
    """Minimal reader for the shapes this script writes: `k: v` and `k:` + `- v`."""
    found = {}
    current = None
    with open(path) as fh:
        for raw in fh:
            line = raw.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            m = re.match(r'^(\S+?)\s*:\s*(.*)$', line)
            if m:
                key, val = m.group(1), m.group(2).strip()
                if val:
                    found[key] = val.strip('"')
                    current = None
                else:
                    current = key
                    found[key] = []
                continue
            m = re.match(r'^-\s*(.+)$', line)
            if m and current:
                found[current].append(m.group(1).strip().strip('"'))
    return found


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--file', default='/etc/wazuh-indexer/opensearch.yml')
    p.add_argument('--node-name', required=True)
    p.add_argument('--seed-hosts', required=True,
                   help='Comma-separated IPs of every node in the cluster.')
    p.add_argument('--initial-managers', required=True,
                   help='Comma-separated node NAMES eligible as cluster manager.')
    p.add_argument('--nodes-dn', required=True,
                   help='Comma-separated node NAMES; expanded to full DNs.')
    p.add_argument('--network-host', default=None,
                   help='Leave unset to keep the shipped value.')
    p.add_argument('--dry-run', action='store_true')
    args = p.parse_args()

    seeds = [s.strip() for s in args.seed_hosts.split(',') if s.strip()]
    managers = [s.strip() for s in args.initial_managers.split(',') if s.strip()]
    dn_names = [s.strip() for s in args.nodes_dn.split(',') if s.strip()]
    dns = [DN_TEMPLATE.format(name=n) for n in dn_names]

    with open(args.file) as fh:
        lines = fh.read().split('\n')

    lines = replace_key(lines, 'node.name', scalar('node.name', args.node_name))
    if args.network_host is not None:
        lines = replace_key(lines, 'network.host',
                            scalar('network.host', args.network_host))
    lines = replace_key(lines, 'discovery.seed_hosts',
                        seq('discovery.seed_hosts', seeds))
    lines = replace_key(lines, 'cluster.initial_cluster_manager_nodes',
                        seq('cluster.initial_cluster_manager_nodes', managers))
    lines = replace_key(lines, 'plugins.security.nodes_dn',
                        seq('plugins.security.nodes_dn', dns))

    out = '\n'.join(lines)

    if args.dry_run:
        sys.stdout.write(out)
        return 0

    shutil.copy2(args.file, '{}.bak.{}'.format(args.file, int(time.time())))
    with open(args.file, 'w') as fh:
        fh.write(out)

    # --- verify, don't assume -------------------------------------------
    got = read_back(args.file)
    problems = []
    if got.get('node.name') != args.node_name:
        problems.append('node.name={!r} expected {!r}'.format(
            got.get('node.name'), args.node_name))
    if got.get('discovery.seed_hosts') != seeds:
        problems.append('discovery.seed_hosts={!r} expected {!r}'.format(
            got.get('discovery.seed_hosts'), seeds))
    if got.get('cluster.initial_cluster_manager_nodes') != managers:
        problems.append('initial_cluster_manager_nodes={!r} expected {!r}'.format(
            got.get('cluster.initial_cluster_manager_nodes'), managers))
    if got.get('plugins.security.nodes_dn') != dns:
        problems.append('nodes_dn={!r} expected {!r}'.format(
            got.get('plugins.security.nodes_dn'), dns))

    # A duplicate top-level key is the specific failure this script exists to
    # prevent, so check for it explicitly rather than trusting the edit.
    for key in ('node.name', 'discovery.seed_hosts',
                'cluster.initial_cluster_manager_nodes',
                'plugins.security.nodes_dn'):
        count = len([l for l in out.split('\n')
                     if re.match(r'^' + re.escape(key) + r'\s*:', l)])
        if count != 1:
            problems.append('{} appears {} times (expected exactly 1)'.format(key, count))

    if problems:
        sys.stderr.write('VERIFY FAILED on {}:\n  {}\n'.format(
            args.file, '\n  '.join(problems)))
        return 1

    print('OK {} node.name={} seeds={} managers={} nodes_dn={}'.format(
        args.file, args.node_name, len(seeds), len(managers), len(dns)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
