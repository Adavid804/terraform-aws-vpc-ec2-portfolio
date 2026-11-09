output "vpc_id" {
  description = "VPC containing the instance."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnets with an IGW route."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnets; NAT routes are enabled only in private mode."
  value       = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  description = "VPC internet gateway."
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs (not EIP allocation IDs); empty in public mode."
  value       = module.vpc.nat_gateway_ids
}

output "instance_subnet_id" {
  description = "Subnet selected for EC2."
  value       = local.instance_subnet_id
}

output "instance_security_group_id" {
  description = "Security group created in the instance VPC."
  value       = aws_security_group.instance.id
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.ec2.instance_id
}

output "instance_arn" {
  description = "EC2 instance ARN."
  value       = module.ec2.instance_arn
}

output "instance_public_ip" {
  description = "Public-mode instance IPv4 address; null in private mode. Auto-assigned addresses can change after stop/start."
  value       = local.is_public ? module.ec2.instance_public_ip : null
}

output "instance_private_ip" {
  description = "Instance private IPv4 address."
  value       = module.ec2.instance_private_ip
}

output "instance_tags" {
  description = "Effective EC2 tags, including provider default tags."
  value       = module.ec2.tags_all
}
