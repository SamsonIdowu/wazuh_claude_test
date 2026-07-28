# TTL & Auto-Termination

## How it works

Every instance schedules its own termination in `user_data`, as the very first
action, before any installation work:

```bash
/sbin/shutdown -h +${resource_ttl_minutes}
```

paired with:

```hcl
instance_initiated_shutdown_behavior = "terminate"
```

Both halves are required:

- **`shutdown -h +N` runs first**, so a hung or failed install still terminates
  on schedule. If it were appended after the install, a failure would leave the
  instance running forever — which is exactly what happened before.
- **`instance_initiated_shutdown_behavior = "terminate"`** makes the shutdown
  terminate rather than *stop* the instance. A stopped instance still bills for
  its EBS volumes.

The mechanism is deliberately local and dumb: no Lambda, no external scheduler,
nothing that can fail silently outside the instance. The instance kills itself.

Verify it was actually scheduled:

```bash
ssh -i wazuh-test-key.pem ubuntu@<IP> "sudo cat /root/TTL_SCHEDULED; shutdown --show"
```

---

## History — why this document is emphatic

This file previously claimed:

> "All deployed resources have a 1-hour default TTL. After this period, the
> infrastructure will be automatically terminated to prevent unexpected costs."

**That was false.** `resource_ttl_minutes` and `enable_auto_termination` produced
only two things:

1. `TTL_AND_EXTENSION.txt`, a local text file *asserting* auto-termination
2. EC2 tags `TTL_Minutes` and `AutoTermination` — inert metadata

No Lambda. No CloudWatch alarm. No scheduled shutdown. Nothing read those tags.
The variables described an intention that no code implemented, and both this
document and the Terraform outputs reported it as though it were real.

Consequence: a test run set to a 240-minute TTL ran for **17 hours** and cost
**~$4.92** before being noticed and destroyed manually. Tags and documentation
are not enforcement.

---

## Configuration

| Variable | Default | Effect |
|---|---|---|
| `resource_ttl_minutes` | 240 | Minutes until self-termination (1–1440) |
| `enable_auto_termination` | `true` | `false` disables the shutdown and sets behaviour to `stop` |

### Extending the TTL

Editing the variable only affects **new** instances. `user_data` runs once, on
first boot, so changing it does not reschedule a running instance.

To extend a *running* instance, reschedule on the box itself:

```bash
sudo shutdown -c                # cancel the pending shutdown
sudo shutdown -h +480           # reschedule for 8 hours
```

To change the default for future deploys, edit `terraform/terraform.tfvars`:

```hcl
resource_ttl_minutes = 480
```

### Disabling auto-termination

```hcl
enable_auto_termination = false
```

With this set you are responsible for teardown. Nothing will stop the billing.

---

## Teardown is still your responsibility

The TTL is a safety net against *forgetting*, not a substitute for cleanup.
When a test finishes:

```bash
cd terraform && terraform destroy -auto-approve
```

Then confirm against AWS rather than trusting the Terraform output:

```bash
aws ec2 describe-instances --profile wazuh \
  --filters "Name=tag:Name,Values=wazuh-server,wazuh-agent,thehive-server" \
  --region us-east-1 \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output table

# Orphaned volumes bill even with no instances:
aws ec2 describe-volumes --profile wazuh --region us-east-1 \
  --filters "Name=status,Values=available" --output table

# Also sweep account-wide: tag-filtered checks alone missed an older,
# differently-tagged deployment that ran for 24 hours before being found.
aws ec2 describe-instances --profile wazuh --region us-east-1 \
  --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`]|[0].Value,State.Name]' \
  --output table
```

---

## Cost reference (us-east-1 on-demand)

| Instance | Type | Rate |
|---|---|---|
| Wazuh server | t3.xlarge | ~$0.1664/hr |
| Wazuh agent | t3.medium | ~$0.0416/hr |
| TheHive | t3.large | ~$0.0832/hr |
| **Combined** | | **~$0.29/hr (~$7/day)** |
