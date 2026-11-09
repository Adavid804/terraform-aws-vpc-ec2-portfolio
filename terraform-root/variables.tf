variable "aws_region" {
  description = "AWS Region in which to create all resources."
  type        = string
  nullable    = false
}

variable "name" {
  description = "Short resource-name prefix, also used by the VPC flow-log IAM role."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,39}$", var.name))
    error_message = "Use 1-40 letters, digits or hyphens, starting with a letter."
  }
}

variable "tags" {
  description = "Resource tags. CostCenter and Environment must have nonempty values."
  type        = map(string)
  nullable    = false

  validation {
    condition = alltrue([
      for key in ["CostCenter", "Environment"] :
      try(trimspace(var.tags[key]) != "", false)
    ])
    error_message = "Supply nonempty CostCenter and Environment tags explicitly."
  }
}

variable "network_mode" {
  description = "public: public subnet + public IPv4 + IGW; private: private subnet + NAT, without public IPv4."
  type        = string
  default     = "public"
  nullable    = false

  validation {
    condition     = contains(["public", "private"], var.network_mode)
    error_message = "network_mode must be public or private."
  }
}

variable "availability_zones" {
  description = "AZ names in aws_region, in subnet order (for example us-east-1a). AZ IDs are not supported by the child module."
  type        = list(string)
  nullable    = false

  validation {
    condition = length(var.availability_zones) > 0 && alltrue([
      for az in var.availability_zones : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+[a-z]$", az)) && startswith(az, var.aws_region)
    ])
    error_message = "Supply at least one standard AZ name in aws_region, not an AZ ID."
  }
}

variable "vpc_cidr" {
  description = "IPv4 VPC CIDR. Choose a range that does not overlap networks you will connect."
  type        = string
  default     = "10.42.0.0/16"
  nullable    = false

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be an IPv4 CIDR."
  }
}

variable "public_subnet_cidrs" {
  description = "Nonoverlapping IPv4 subnet CIDRs inside vpc_cidr; one per supplied AZ."
  type        = list(string)
  default     = ["10.42.1.0/24"]
  nullable    = false

  validation {
    condition = (
      length(var.public_subnet_cidrs) == length(var.availability_zones) &&
      length(var.public_subnet_cidrs) > 0 &&
      alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    )
    error_message = "Supply one valid IPv4 public subnet CIDR per AZ."
  }
}

variable "private_subnet_cidrs" {
  description = "Nonoverlapping IPv4 subnet CIDRs inside vpc_cidr; empty or one per AZ. Required in private mode."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = (
      (length(var.private_subnet_cidrs) == 0 || length(var.private_subnet_cidrs) == length(var.availability_zones)) &&
      (var.network_mode != "private" || length(var.private_subnet_cidrs) > 0) &&
      alltrue([for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))])
    )
    error_message = "Supply one valid IPv4 private subnet CIDR per AZ in private mode; public mode also permits an empty list."
  }
}

variable "subnet_index" {
  description = "Zero-based index of the public/private subnet in which to launch the instance."
  type        = number
  default     = 0
  nullable    = false

  validation {
    condition = (
      var.subnet_index >= 0 && floor(var.subnet_index) == var.subnet_index &&
      var.subnet_index < length(var.network_mode == "public" ? var.public_subnet_cidrs : var.private_subnet_cidrs)
    )
    error_message = "subnet_index must select an existing subnet in the selected network_mode."
  }
}

variable "single_nat_gateway" {
  description = "In private mode, share one NAT in the first public subnet; false creates one per private subnet/AZ."
  type        = bool
  default     = true
  nullable    = false
}

variable "instance_type" {
  description = "Instance type permitted by the EC2 module's existing cost guardrail."
  type        = string
  default     = "t3.micro"
  nullable    = false

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Use t3.micro, t3.small, or t3.medium."
  }
}

variable "ami_id" {
  description = "Regional x86_64 AMI ID; empty lets the child module discover the latest Amazon Linux 2023 image. Pin for repeatable deployments."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = var.ami_id == "" || can(regex("^ami-[0-9a-f]{8}([0-9a-f]{9})?$", var.ami_id))
    error_message = "ami_id must be empty or an AMI ID."
  }
}

variable "iam_instance_profile" {
  description = "Optional existing instance profile NAME. For Session Manager, it needs SSM permissions and the AMI needs a running SSM agent."
  type        = string
  default     = null
}

variable "key_name" {
  description = "Optional existing EC2 key-pair name in aws_region, required if ssh_allowed_cidrs is nonempty."
  type        = string
  default     = null
}

variable "ssh_allowed_cidrs" {
  description = "IPv4 administrator networks (/24 through /32) allowed to SSH in public mode. Empty disables SSH ingress."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for cidr in var.ssh_allowed_cidrs : can(cidrnetmask(cidr)) && can(regex("/(2[4-9]|3[0-2])$", cidr))
    ])
    error_message = "Use IPv4 administrator CIDRs from /24 through /32. Prefer a single administrator address (/32)."
  }

  validation {
    condition = length(var.ssh_allowed_cidrs) == 0 || (
      var.network_mode == "public" && try(trimspace(var.key_name) != "", false)
    )
    error_message = "For direct SSH, select public mode and provide an existing key_name. Use Session Manager or private connectivity in private mode."
  }
}

variable "root_volume_size" {
  description = "Encrypted gp3 root volume size in GiB; must also be at least the chosen AMI snapshot size."
  type        = number
  default     = 20
  nullable    = false

  validation {
    condition     = var.root_volume_size >= 1 && floor(var.root_volume_size) == var.root_volume_size
    error_message = "root_volume_size must be a positive whole number of GiB."
  }
}

variable "root_volume_kms_key_id" {
  description = "Optional regional EBS KMS key ARN; null uses the account's default EBS encryption key."
  type        = string
  default     = null
}

variable "monitoring" {
  description = "Enable detailed EC2 monitoring."
  type        = bool
  default     = false
  nullable    = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable the VPC module's CloudWatch flow logs and associated IAM resources."
  type        = bool
  default     = true
  nullable    = false
}

variable "flow_log_kms_key_id" {
  description = "Optional CloudWatch Logs KMS key ARN; its policy must permit the regional Logs service."
  type        = string
  default     = null
}
