module "public_ec2" {
  source = "./modules/public_ec2"

  name_prefix             = var.name_prefix
  environment             = var.environment
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidr      = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  instance_type           = var.instance_type
  ami_id                  = var.ami_id
  root_volume_size        = var.root_volume_size
  allowed_icmp_ipv4_cidrs = var.allowed_icmp_ipv4_cidrs
  ping_target_ipv4        = var.ping_target_ipv4
  tags                    = var.tags
}
