resource "aws_security_group" "instance" {
  name_prefix = "ec2-${var.name}-"
  description = "EC2 internet egress and optional restricted SSH"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-ec2" })

  lifecycle {
    create_before_destroy = true
  }
}

# General IPv4 internet access. Narrow protocols/destinations if the workload
# only needs specific services. No ingress rule is needed for response traffic.
resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.instance.id
  description       = "Allow outbound IPv4 traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = var.tags
}

# No inbound access by default. SSH requires an existing regional key pair.
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = var.ssh_allowed_cidrs

  security_group_id = aws_security_group.instance.id
  description       = "SSH from an explicitly allowed administrator network"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22

  tags = var.tags
}
