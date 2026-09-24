# Override file: attaches the SSM instance profile defined in ssm-ttl-access.tf
# to the two instances declared in main.tf. Kept separate because Terraform
# treats EVERY block in a *_override.tf as an override of an existing block, so
# the IAM resources themselves cannot live here.
resource "aws_instance" "wazuh_server" {
  iam_instance_profile = aws_iam_instance_profile.ssm.name
}

resource "aws_instance" "wazuh_agent" {
  iam_instance_profile = aws_iam_instance_profile.ssm.name
}
