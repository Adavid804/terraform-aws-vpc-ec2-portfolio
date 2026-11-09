output "aws_region" {
  description = "AWS Region containing the deployment."
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.public_ec2.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = module.public_ec2.public_subnet_id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = module.public_ec2.internet_gateway_id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = module.public_ec2.public_route_table_id
}

output "security_group_id" {
  description = "ID of the instance security group."
  value       = module.public_ec2.security_group_id
}

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = module.public_ec2.instance_id
}

output "instance_public_ipv4" {
  description = "Auto-assigned public IPv4 address of the EC2 instance."
  value       = module.public_ec2.instance_public_ipv4
}

output "instance_private_ipv4" {
  description = "Private IPv4 address of the EC2 instance."
  value       = module.public_ec2.instance_private_ipv4
}

output "ping_target_ipv4" {
  description = "Public IPv4 address used by the connectivity smoke test."
  value       = var.ping_target_ipv4
}

output "ssm_start_session_command" {
  description = "AWS CLI command for opening a Session Manager shell."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${module.public_ec2.instance_id}"
}
