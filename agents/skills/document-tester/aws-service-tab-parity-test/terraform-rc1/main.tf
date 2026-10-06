# awsrc1 - "Monitoring AWS" 4.14 vs 5.0 RC1 regression run, 2026-10-01.
# One shared log bucket (created by CLI: wazuh-rc1-logs-<acct>) read by two Wazuh hosts.
terraform {
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.0" }
    tls   = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "wazuh"
  default_tags {
    tags = { Owner = "wazuh-content-team", Test = "awsrc1" }
  }
}

variable "my_ip" { type = string }
variable "ttl_minutes" {
  type    = number
  default = 240
  validation {
    condition     = var.ttl_minutes > 0 && var.ttl_minutes <= 240
    error_message = "TTL is capped at 240 minutes (standing 4-hour rule)."
  }
}

locals {
  acct     = "257527264356"
  main     = "wazuh-rc1-logs-${local.acct}"
  main_arn = "arn:aws:s3:::wazuh-rc1-logs-${local.acct}"
  me       = "${var.my_ip}/32"
}

data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b"]
  }
}
data "aws_ami" "noble" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# ---------------- SSH key ----------------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "rc1" {
  key_name   = "wazuh-rc1-key"
  public_key = tls_private_key.ssh.public_key_openssh
}
resource "local_file" "pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/wazuh-rc1-key.pem"
  file_permission = "0600"
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "icacls '${self.filename}' /inheritance:r /grant:r \"$($env:USERNAME):(R)\""
  }
}

# ---------------- Security groups ----------------
resource "aws_security_group" "hosts" {
  name        = "wazuh-rc1-hosts-sg"
  description = "awsrc1 Wazuh hosts"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.me]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.me, data.aws_vpc.default.cidr_block]
    description = "dashboard from tester; NLB health checks from VPC"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "lb" {
  name        = "wazuh-rc1-lb-sg"
  description = "awsrc1 ALB/CLB, tester only"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.me]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------- Instance role (the doc's "IAM roles for EC2 instances" auth path) ----------------
# Deliberately has NO ec2:RunInstances/StartInstances/... and NO iam:CreateUser, so the same
# role produces the "action without permissions" CloudTrail use cases.
resource "aws_iam_role" "reader" {
  name = "wazuh-rc1-reader-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy" "reader" {
  name = "wazuh-rc1-reader"
  role = aws_iam_role.reader.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"],
        Resource = [for b in [local.main, aws_s3_bucket.custom.id, aws_s3_bucket.sechub.id, aws_s3_bucket.seclake.id] : "arn:aws:s3:::${b}"]
      },
      { Effect = "Allow", Action = ["s3:GetObject"],
        Resource = [for b in [local.main, aws_s3_bucket.custom.id, aws_s3_bucket.sechub.id, aws_s3_bucket.seclake.id] : "arn:aws:s3:::${b}/*"]
      },
      { Effect = "Allow", Action = ["kms:Decrypt"], Resource = "*" },
      { Effect = "Allow", Action = ["ec2:DescribeFlowLogs"], Resource = "*" },
      { Effect = "Allow", Action = ["inspector:ListFindings", "inspector:DescribeFindings", "inspector2:ListFindings"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:DescribeLogStreams", "logs:GetLogEvents", "logs:DescribeLogGroups", "logs:FilterLogEvents"], Resource = "*" },
      { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"],
        Resource = [aws_sqs_queue.custom.arn, aws_sqs_queue.sechub.arn, aws_sqs_queue.seclake.arn]
      },
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:DescribeRepositories", "ecr:DescribeImages"],
      Resource = "arn:aws:ecr:us-east-1:${local.acct}:repository/wazuh-rc1-repo" }
    ]
  })
}
# Security Lake subscriber role (the doc's <iam_role_arn> + <external_id>); assumed by the reader role.
resource "aws_iam_role" "seclake" {
  name = "wazuh-rc1-seclake-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = aws_iam_role.reader.arn }, Action = "sts:AssumeRole",
    Condition = { StringEquals = { "sts:ExternalId" = ["WAZUH-EXTERNAL-ID-VALUE"] } } }]
  })
}
resource "aws_iam_role_policy" "seclake" {
  name = "wazuh-rc1-seclake-read"
  role = aws_iam_role.seclake.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject", "s3:ListBucket"], Resource = [aws_s3_bucket.seclake.arn, "${aws_s3_bucket.seclake.arn}/*"] },
      { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"], Resource = aws_sqs_queue.seclake.arn }
    ]
  })
}
resource "aws_iam_role_policy" "reader_assume" {
  name = "wazuh-rc1-reader-assume-seclake"
  role = aws_iam_role.reader.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = aws_iam_role.seclake.arn }] })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.reader.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "reader" {
  name = "wazuh-rc1-reader-profile"
  role = aws_iam_role.reader.name
}

# ---------------- Wazuh hosts ----------------
resource "aws_instance" "v4" {
  ami                                  = data.aws_ami.noble.id
  instance_type                        = "t3.xlarge"
  key_name                             = aws_key_pair.rc1.key_name
  subnet_id                            = data.aws_subnets.default.ids[0]
  vpc_security_group_ids               = [aws_security_group.hosts.id]
  iam_instance_profile                 = aws_iam_instance_profile.reader.name
  instance_initiated_shutdown_behavior = "terminate"
  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  user_data = templatefile("${path.module}/user_data_v4.sh.tpl", { ttl = var.ttl_minutes })
  tags      = { Name = "wazuh-rc1-v4" }
}
resource "aws_instance" "v5" {
  ami                                  = data.aws_ami.noble.id
  instance_type                        = "t3.xlarge"
  key_name                             = aws_key_pair.rc1.key_name
  subnet_id                            = data.aws_subnets.default.ids[0]
  vpc_security_group_ids               = [aws_security_group.hosts.id]
  iam_instance_profile                 = aws_iam_instance_profile.reader.name
  instance_initiated_shutdown_behavior = "terminate"
  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  user_data = templatefile("${path.module}/user_data_v5.sh.tpl", {
    ttl      = var.ttl_minutes
    yaml_b64 = filebase64("${path.module}/artifact_urls.yaml")
  })
  tags = { Name = "wazuh-rc1-v5" }
}

# ---------------- Subscriber buckets + queues (Custom Logs, Security Hub, Security Lake emulation) ----------------
resource "aws_s3_bucket" "custom" {
  bucket        = "wazuh-rc1-custom-${local.acct}"
  force_destroy = true
}
resource "aws_s3_bucket" "sechub" {
  bucket        = "wazuh-rc1-sechub-${local.acct}"
  force_destroy = true
}
resource "aws_s3_bucket" "seclake" {
  bucket        = "wazuh-rc1-seclake-${local.acct}"
  force_destroy = true
}

# Custom Logs: the doc's queue access policy, verbatim apart from placeholders.
resource "aws_sqs_queue" "custom" { name = "wazuh-rc1-custom" }
resource "aws_sqs_queue_policy" "custom" {
  queue_url = aws_sqs_queue.custom.id
  policy = jsonencode({
    Version = "2012-10-17", Id = "example-ID",
    Statement = [{ Sid = "example-access-policy", Effect = "Allow", Principal = { Service = "s3.amazonaws.com" },
      Action = "SQS:SendMessage", Resource = aws_sqs_queue.custom.arn,
      Condition = { StringEquals = { "aws:SourceAccount" = local.acct }, ArnLike = { "aws:SourceArn" = "arn:aws:s3:*:*:${aws_s3_bucket.custom.id}" } }
    }]
  })
}
resource "aws_s3_bucket_notification" "custom" {
  bucket = aws_s3_bucket.custom.id
  queue {
    queue_arn = aws_sqs_queue.custom.arn
    events    = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_sqs_queue_policy.custom]
}

# Security Hub: corrected queue ARN (the doc repeats the account ID in it).
resource "aws_sqs_queue" "sechub" { name = "wazuh-rc1-sechub" }
resource "aws_sqs_queue_policy" "sechub" {
  queue_url = aws_sqs_queue.sechub.id
  policy = jsonencode({
    Version = "2012-10-17", Id = "SecurityHub-ID",
    Statement = [{ Sid = "example-access-policy", Effect = "Allow", Principal = { Service = "s3.amazonaws.com" },
      Action = "SQS:SendMessage", Resource = aws_sqs_queue.sechub.arn,
      Condition = { StringEquals = { "aws:SourceAccount" = local.acct }, ArnLike = { "aws:SourceArn" = "arn:aws:s3:*:*:${aws_s3_bucket.sechub.id}" } }
    }]
  })
}
resource "aws_s3_bucket_notification" "sechub" {
  bucket = aws_s3_bucket.sechub.id
  queue {
    queue_arn = aws_sqs_queue.sechub.arn
    events    = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_sqs_queue_policy.sechub]
}

# Security Lake emulation (subscriber creation is blocked by an Org guardrail in this account):
# S3 -> EventBridge "Object Created" -> SQS, which is the message shape a Security Lake subscriber queue carries.
resource "aws_sqs_queue" "seclake" { name = "wazuh-rc1-seclake" }
resource "aws_sqs_queue_policy" "seclake" {
  queue_url = aws_sqs_queue.seclake.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sqs:SendMessage",
    Resource = aws_sqs_queue.seclake.arn, Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.seclake.arn } } }]
  })
}
resource "aws_s3_bucket_notification" "seclake" {
  bucket      = aws_s3_bucket.seclake.id
  eventbridge = true
}
resource "aws_cloudwatch_event_rule" "seclake" {
  name = "wazuh-rc1-seclake-objects"
  event_pattern = jsonencode({ source = ["aws.s3"], "detail-type" = ["Object Created"],
  detail = { bucket = { name = [aws_s3_bucket.seclake.id] } } })
}
resource "aws_cloudwatch_event_target" "seclake" {
  rule = aws_cloudwatch_event_rule.seclake.name
  arn  = aws_sqs_queue.seclake.arn
}

# ---------------- Firehose streams (KMS, Macie, WAF, Security Hub) + EventBridge ----------------
resource "aws_iam_role" "firehose" {
  name = "wazuh-rc1-firehose-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17",
  Statement = [{ Effect = "Allow", Principal = { Service = "firehose.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy" "firehose" {
  name = "wazuh-rc1-firehose-s3"
  role = aws_iam_role.firehose.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow",
    Action   = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:PutObject"],
  Resource = [local.main_arn, "${local.main_arn}/*", aws_s3_bucket.sechub.arn, "${aws_s3_bucket.sechub.arn}/*"] }] })
}
locals {
  streams = {
    kms    = { name = "wazuh-rc1-kms", prefix = "kms_compress_encrypted/", bucket = local.main_arn, gzip = true }
    macie  = { name = "wazuh-rc1-macie", prefix = "macie/", bucket = local.main_arn, gzip = false }
    waf    = { name = "aws-waf-logs-wazuh-rc1", prefix = "waf/", bucket = local.main_arn, gzip = false }
    sechub = { name = "wazuh-rc1-sechub", prefix = "", bucket = aws_s3_bucket.sechub.arn, gzip = false }
  }
}
resource "aws_kinesis_firehose_delivery_stream" "s" {
  for_each    = local.streams
  name        = each.value.name
  destination = "extended_s3"
  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose.arn
    bucket_arn         = each.value.bucket
    prefix             = each.value.prefix
    buffering_interval = 60
    buffering_size     = 1
    compression_format = each.value.gzip ? "GZIP" : "UNCOMPRESSED"
  }
}
resource "aws_iam_role" "events" {
  name = "wazuh-rc1-events-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17",
  Statement = [{ Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy" "events" {
  name = "wazuh-rc1-events-firehose"
  role = aws_iam_role.events.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["firehose:PutRecord", "firehose:PutRecordBatch"],
  Resource = [for k in ["kms", "macie", "sechub"] : aws_kinesis_firehose_delivery_stream.s[k].arn] }] })
}
locals {
  rules = { kms = "aws.kms", macie = "aws.macie", sechub = "aws.securityhub" }
}
resource "aws_cloudwatch_event_rule" "svc" {
  for_each      = local.rules
  name          = "wazuh-rc1-${each.key}"
  event_pattern = jsonencode({ source = [each.value] })
}
resource "aws_cloudwatch_event_target" "svc" {
  for_each = local.rules
  rule     = aws_cloudwatch_event_rule.svc[each.key].name
  arn      = aws_kinesis_firehose_delivery_stream.s[each.key].arn
  role_arn = aws_iam_role.events.arn
}

# ---------------- Load balancers (ALB, CLB, NLB with TLS) ----------------
resource "aws_lb" "alb" {
  name               = "wazuh-rc1-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.lb.id]
  access_logs {
    bucket  = local.main
    prefix  = "ALB"
    enabled = true
  }
}
resource "aws_lb_listener" "alb" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "awsrc1 ok"
      status_code  = "200"
    }
  }
}
resource "aws_lb_listener_rule" "alb_403" {
  listener_arn = aws_lb_listener.alb.arn
  priority     = 10
  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "403"
    }
  }
  condition {
    path_pattern { values = ["/forbidden*"] }
  }
}
resource "aws_lb_listener_rule" "alb_503" {
  listener_arn = aws_lb_listener.alb.arn
  priority     = 20
  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "503"
    }
  }
  condition {
    path_pattern { values = ["/unavailable*"] }
  }
}
resource "aws_elb" "clb" {
  name            = "wazuh-rc1-clb"
  subnets         = data.aws_subnets.default.ids
  security_groups = [aws_security_group.lb.id]
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  access_logs {
    bucket        = local.main
    bucket_prefix = "CLB"
    interval      = 5
    enabled       = true
  }
}
resource "tls_private_key" "nlb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_self_signed_cert" "nlb" {
  private_key_pem       = tls_private_key.nlb.private_key_pem
  validity_period_hours = 48
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
  subject {
    common_name = "nlb.awsrc1.test"
  }
}
resource "aws_acm_certificate" "nlb" {
  private_key      = tls_private_key.nlb.private_key_pem
  certificate_body = tls_self_signed_cert.nlb.cert_pem
}
resource "aws_lb" "nlb" {
  name               = "wazuh-rc1-nlb"
  load_balancer_type = "network"
  subnets            = data.aws_subnets.default.ids
  access_logs {
    bucket  = local.main
    prefix  = "NLB"
    enabled = true
  }
}
resource "aws_lb_target_group" "nlb" {
  name        = "wazuh-rc1-nlb-tg"
  port        = 443
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"
}
resource "aws_lb_target_group_attachment" "nlb" {
  target_group_arn = aws_lb_target_group.nlb.arn
  target_id        = aws_instance.v4.id
  port             = 443
}
resource "aws_lb_listener" "nlb" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 443
  protocol          = "TLS"
  certificate_arn   = aws_acm_certificate.nlb.arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb.arn
  }
}

# ---------------- WAF on the ALB ----------------
resource "aws_wafv2_web_acl" "acl" {
  name  = "wazuh-rc1-acl"
  scope = "REGIONAL"
  default_action {
    allow {}
  }
  rule {
    name     = "block-admin-path"
    priority = 1
    action {
      block {}
    }
    statement {
      byte_match_statement {
        search_string         = "/admin"
        positional_constraint = "STARTS_WITH"
        field_to_match {
          uri_path {}
        }
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "block-admin-path"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "aws-sqli"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "aws-sqli"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "wazuh-rc1-acl"
    sampled_requests_enabled   = true
  }
}
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.acl.arn
}
resource "aws_wafv2_web_acl_logging_configuration" "acl" {
  resource_arn            = aws_wafv2_web_acl.acl.arn
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.s["waf"].arn]
}

output "v4_ip" { value = aws_instance.v4.public_ip }
output "v5_ip" { value = aws_instance.v5.public_ip }
output "v4_id" { value = aws_instance.v4.id }
output "v5_id" { value = aws_instance.v5.id }
output "alb" { value = aws_lb.alb.dns_name }
output "clb" { value = aws_elb.clb.dns_name }
output "nlb" { value = aws_lb.nlb.dns_name }
