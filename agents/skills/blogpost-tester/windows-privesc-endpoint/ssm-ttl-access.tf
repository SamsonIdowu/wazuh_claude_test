# ═══════════════════════════════════════════════════════════════════════════
# SSM access — so a TTL can still be re-armed in its last 5 minutes
#
# WHY THIS EXISTS (2026-09-23): a TTL extension was requested 2 minutes before
# expiry and could not be honoured. `shutdown -h +N` makes systemd write
# /run/nologin 5 minutes ahead of the deadline, and pam_nologin then rejects
# EVERY ssh login — including `ssh host 'sudo shutdown -c'`. The one command
# that cancels the timer needs the one channel the timer has already closed.
# Both Linux hosts terminated with the operator locked out.
#
# SSM Run Command does not go through PAM, so it still reaches the box inside
# that window. This is a recovery path, NOT a second TTL mechanism — the
# in-guest `shutdown` + instance_initiated_shutdown_behavior = "terminate"
# remains the enforcement.
#
# The SSM Agent is preinstalled on both Amazon's Ubuntu and Windows Server
# AMIs; it only needs this instance profile to register.
# ═══════════════════════════════════════════════════════════════════════════

data "aws_iam_policy_document" "ssm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "wazuh-test-ssm-${var.wazuh_version}"
  assume_role_policy = data.aws_iam_policy_document.ssm_assume.json

  tags = {
    Name    = "wazuh-test-ssm-${var.wazuh_version}"
    Purpose = "TTL re-arm path that survives pam_nologin"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "wazuh-test-ssm-${var.wazuh_version}"
  role = aws_iam_role.ssm.name
}

output "ttl_rearm_commands" {
  description = "How to cancel or extend the TTL once ssh is blocked by pam_nologin"
  value = [
    "Linux  cancel : aws ssm send-command --profile wazuh --instance-ids <id> --document-name AWS-RunShellScript --parameters 'commands=[\"shutdown -c\"]'",
    "Linux  re-arm : aws ssm send-command --profile wazuh --instance-ids <id> --document-name AWS-RunShellScript --parameters 'commands=[\"shutdown -h +120\"]'",
    "Windows re-arm: aws ssm send-command --profile wazuh --instance-ids <id> --document-name AWS-RunPowerShellScript --parameters 'commands=[\"shutdown.exe /a; shutdown.exe /s /t 7200\"]'",
    "Verify Windows armed: run 'shutdown /s /t 7200' twice - the second must return 1190",
  ]
}
