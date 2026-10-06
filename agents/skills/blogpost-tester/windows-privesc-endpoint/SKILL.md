---
name: windows-privesc-endpoint
description: Add a Windows endpoint with an auto-enrolling Wazuh agent to the baseline terraform, plus an SSM path that keeps the TTL re-armable. Use when testing any blog post or document that needs a Windows agent — privilege escalation, Sysmon, registry or scheduled-task detections.
---

# Windows endpoint for blog testing

The baseline `terraform/` builds a manager and a *Linux* agent only. Any post
that needs a Windows endpoint has to add one. This is that addition, tested end
to end on the "Detecting common Windows privilege escalation techniques"
post (2026-09-23): agent enrolled, Sysmon configured, all five custom rules
firing.

## Files

| File | What it is |
|---|---|
| `windows-agent-init.ps1` | `user_data`. Waits for the manager's port 1515, installs the agent MSI, self-heals enrollment via `agent-auth.exe`. |

The repo keeps Terraform only for the baseline Wazuh server and agent in
`terraform/`. Write the Windows host's Terraform for each run, in the
ephemeral test directory, and delete it at cleanup. It needs:

- A Windows Server 2022 instance (AMI lookup: `owners=amazon`,
  `Windows_Server-2022-English-Full-Base-*`) with `windows-agent-init.ps1` as
  `user_data` and `user_data_replace_on_change = true`.
- Its own security group: RDP/WinRM from an `allowed_rdp_cidrs` variable with
  **no default**, so the tester's /32 is supplied at plan time and never
  committed.
- An IAM role and instance profile with `AmazonSSMManagedInstanceCore`, attached
  to every host in the run, including the baseline manager and agent. Not
  optional — see TTL below. Attach it to the baseline instances through a
  `*_override.tf` file that holds **only** the `iam_instance_profile`
  overrides; Terraform treats every block in an override file as an override,
  so the IAM resources must live in a separate file.

## There is no Windows 11 AMI on EC2

Posts routinely specify Windows 11. EC2 does not offer it — Windows 11 needs a
Dedicated Host with BYOL media, which outlives the 4h TTL policy. Searching
`owners=amazon, platform=windows, name=*Windows*11*` returns ~26 images and
**every one is a false match** (`WindowsServer2022Core`, `EKS_Optimized-1.30`).
Print the names before concluding one exists.

Windows Server 2022 is a safe substitute for service/registry/scheduled-task/DLL
and Sysmon EID 1/7/11/13 work. It is **not** safe for consumer-only surface
(Windows Security UI, Store/AppX, consumer Defender defaults). Say in the report
that the substitution was made.

## TTL: the in-guest timer is uncancellable in its last 5 minutes

`shutdown -h +N` makes systemd write `/run/nologin` 5 minutes before the
deadline, and `pam_nologin` then rejects **every** ssh login — including
`ssh host 'sudo shutdown -c'`. The command that cancels the timer needs the
channel the timer has already closed. Two Linux hosts were lost this way.

SSM Run Command does not go through PAM, so it still reaches the box. That is
why the SSM instance profile is not optional. Re-arm with:

```bash
aws ssm send-command --profile wazuh --region us-east-1 --instance-ids <id> \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["shutdown -c","shutdown -h +120"]'
```

Windows uses `AWS-RunPowerShellScript` with `shutdown.exe /a; shutdown.exe /s /t 7200`.
**Verify it armed** — run the arm command twice; only a `1190`
("already scheduled") proves a timer exists. Exit code 0 alone does not, and
`shutdown.exe /a` leaves the host with *no* timer until you re-arm it.

Never extend a TTL by editing `resource_ttl_minutes`: that rewrites `user_data`
and force-replaces every TTL-tracked instance, destroying what you were trying
to keep.

## Traps

- **`user_data` does not force replacement by default.** Rebuilding the manager
  gives it a new private IP, so the Windows `user_data` changes — but Terraform
  reports an in-place `update` and the running agent stays pointed at the dead
  manager. Always set `user_data_replace_on_change = true` on the Windows
  instance for this reason.
- **No `0.0.0.0/0` on RDP.** The permission classifier blocks it as
  `[Security Weaken]`, in a `.tf` file just as much as in a live command.
  Pass the tester's own address at plan time, never as a committed default:
  `-var 'allowed_rdp_cidrs=["'"$(curl -s https://checkip.amazonaws.com)"'/32"]'`.
- **WinRM over HTTPS works; `Start-Process -Credential` does not.** The latter
  needs an interactive logon and fails `Access is denied` under WinRM. Connect
  with `New-PSSessionOption -SkipCACheck -SkipCNCheck` (the listener cert is
  self-signed for the NetBIOS name, not the FQDN). Adding
  `-SkipRevocationCheck` gets the call blocked by the classifier.
- **`Sysmon64.exe -c` output is UTF-16.** A naive `.Contains()` or grep returns
  false for strings that *are* present. Strip nulls first:
  `(Get-Content f -Raw) -replace "\`0",""`. This cost a wrong root-cause call.
- **Run a standard user's commands via a scheduled task.** Grant
  `SeBatchLogonRight` with `secedit` first — a standard user does not have it,
  and without it the task silently never runs (`LastTaskResult 0x00041303`).
  A batch logon also creates the profile and mounts the user's registry hive,
  which is what `HKEY_USERS\<sid>` writes need.
- **`HKCU\Software\Policies` is read-only for standard users** by design
  (`Requested registry access is not allowed`). Policy values must be written by
  an administrator against `HKEY_USERS\<sid>`.
- **Vulnerability detection fills a 30 GB root disk.** Two copies of the CTI
  feed (~20.6 GB) cross the indexer's 95% flood-stage watermark, which sets
  `read_only_allow_delete` on every index and stops indexing while filebeat
  still reports healthy. Either disable it or size the volume at 100 GB.
