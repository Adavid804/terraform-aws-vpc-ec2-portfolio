variable "aws_region" {
  description = "AWS Region in which to deploy the stack."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for resource names and Name tags."
  type        = string
  default     = "public-ec2"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,40}$", var.name_prefix))
    error_message = "name_prefix must contain 1-40 letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Environment value applied to resource tags."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zone" {
  description = "Optional Availability Zone for the public subnet. AWS selects one when null."
  type        = string
  default     = null
  nullable    = true
}

variable "instance_type" {
  description = "EC2 instance type. The default is a small burstable x86 instance."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Optional AMI ID. When null, the latest Amazon Linux 2023 x86_64 AMI is selected."
  type        = string
  default     = null
  nullable    = true
}

variable "root_volume_size" {
  description = "Size in GiB of the encrypted gp3 root volume."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}

variable "allowed_icmp_ipv4_cidrs" {
  description = "IPv4 CIDRs that may receive ICMP echo requests from the instance."
  type        = list(string)
  default     = ["1.1.1.1/32"]

  validation {
    condition     = length(var.allowed_icmp_ipv4_cidrs) > 0 && alltrue([for cidr in var.allowed_icmp_ipv4_cidrs : can(cidrnetmask(cidr))])
    error_message = "allowed_icmp_ipv4_cidrs must contain at least one valid IPv4 CIDR block."
  }
}

variable "ping_target_ipv4" {
  description = "Public IPv4 address pinged once at first boot for the connectivity smoke test."
  type        = string
  default     = "1.1.1.1"

  validation {
    condition     = can(cidrnetmask("${var.ping_target_ipv4}/32"))
    error_message = "ping_target_ipv4 must be a valid IPv4 address without a CIDR suffix."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
