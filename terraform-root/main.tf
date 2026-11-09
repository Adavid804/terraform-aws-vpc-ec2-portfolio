locals {
  is_public = var.network_mode == "public"
  instance_subnet_id = try(
    (local.is_public ? module.vpc.public_subnet_ids : module.vpc.private_subnet_ids)[var.subnet_index],
    null
  )
}

module "vpc" {
  # Reviewed main commit, pinned for reproducible module installation.
  source = "git::https://github.com/Adavid804/terraform-aws-vpc.git?ref=cec4cdacc954e5685823794df69c176fd934fd52"

  vpc_name         = "${var.name}-vpc"
  cidr_block       = var.vpc_cidr
  azs              = var.availability_zones
  public_subnets   = var.public_subnet_cidrs
  private_subnets  = var.private_subnet_cidrs
  database_subnets = []

  # Public EC2 uses the IGW directly. Private EC2 needs a public NAT gateway.
  enable_nat_gateway = !local.is_public
  single_nat_gateway = var.single_nat_gateway

  enable_vpc_flow_logs = var.enable_vpc_flow_logs
  flow_log_kms_key_id  = var.flow_log_kms_key_id
  mandatory_tags       = var.tags
}

module "ec2" {
  # Reviewed main commit; retain the module's IMDSv2 and encrypted EBS defaults.
  source = "git::https://github.com/Adavid804/terraform-aws-ec2.git?ref=8afd1f04e1aa185ecd00025691ad01c7efae2818"

  instance_name               = "${var.name}-ec2"
  instance_type               = var.instance_type
  ami_id                      = var.ami_id
  subnet_id                   = local.instance_subnet_id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  associate_public_ip_address = local.is_public
  iam_instance_profile        = var.iam_instance_profile
  key_name                    = var.key_name
  root_volume_size            = var.root_volume_size
  root_volume_kms_key_id      = var.root_volume_kms_key_id
  monitoring                  = var.monitoring

  # Passing tags here is required by the child module's validation.
  tags = var.tags

  # Subnet IDs alone do not wait for routes, route associations, or SG rules.
  depends_on = [
    module.vpc,
    aws_vpc_security_group_egress_rule.internet,
    aws_vpc_security_group_ingress_rule.ssh,
  ]
}
