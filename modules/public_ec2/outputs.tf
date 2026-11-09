output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "security_group_id" {
  description = "ID of the EC2 security group."
  value       = aws_security_group.instance.id
}

output "instance_profile_name" {
  description = "Name of the EC2 IAM instance profile."
  value       = aws_iam_instance_profile.instance.name
}

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "instance_public_ipv4" {
  description = "Auto-assigned public IPv4 address of the EC2 instance."
  value       = aws_instance.this.public_ip
}

output "instance_private_ipv4" {
  description = "Private IPv4 address of the EC2 instance."
  value       = aws_instance.this.private_ip
}
