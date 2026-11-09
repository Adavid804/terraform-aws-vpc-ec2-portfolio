locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  instance_ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux[0].id
}

data "aws_ami" "amazon_linux" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public"
    Tier = "public"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public"
  })
}

resource "aws_route" "internet_ipv4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "instance" {
  name_prefix            = "${var.name_prefix}-"
  description            = "No ingress; restricted egress for ICMP testing and SSM"
  vpc_id                 = aws_vpc.this.id
  revoke_rules_on_delete = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-instance"
  })
}

resource "aws_vpc_security_group_egress_rule" "icmp_echo_request" {
  for_each = toset(var.allowed_icmp_ipv4_cidrs)

  security_group_id = aws_security_group.instance.id
  description       = "Allow outbound ICMP echo requests to ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.instance.id
  description       = "Allow HTTPS egress for Systems Manager and package repositories"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_iam_role" "instance" {
  name               = "${var.name_prefix}-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name_prefix}-ssm"
  role = aws_iam_role.instance.name

  tags = local.common_tags
}

resource "aws_instance" "this" {
  ami                         = local.instance_ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
  }

  dynamic "credit_specification" {
    for_each = can(regex("^t(2|3a?|4g)\\.", var.instance_type)) ? [1] : []

    content {
      cpu_credits = "standard"
    }
  }

  user_data = <<-EOT
    #!/bin/bash
    set -u

    systemctl enable --now amazon-ssm-agent || true
    PING_TARGET=${jsonencode(var.ping_target_ipv4)}
    ping -c 4 -W 5 "$PING_TARGET" > /var/log/internet-connectivity-test.log 2>&1 || true
  EOT

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-instance"
  })

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core,
    aws_route.internet_ipv4,
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.https,
    aws_vpc_security_group_egress_rule.icmp_echo_request,
  ]
}
