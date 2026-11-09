# All resources and data sources use Terraform's mock AWS provider.
mock_provider "aws" {
  mock_resource "aws_instance" {
    defaults = {
      public_ip = "192.0.2.20"
    }
  }
}

variables {
  name                 = "connectivity-test"
  aws_region           = "us-east-1"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.42.1.0/24", "10.42.2.0/24"]
  ami_id               = "ami-0123456789abcdef0"
  enable_vpc_flow_logs = false
  tags = {
    CostCenter  = "example"
    Environment = "test"
  }
}

run "public_defaults" {
  command = apply

  assert {
    condition = (
      output.instance_subnet_id == output.public_subnet_ids[0] &&
      output.instance_public_ip == "192.0.2.20" &&
      output.internet_gateway_id != "" &&
      length(output.nat_gateway_ids) == 0
    )
    error_message = "Public mode must select a public subnet, expose the instance IPv4 address, and use an IGW without NAT."
  }

  assert {
    condition = (
      aws_security_group.instance.vpc_id == output.vpc_id &&
      length(aws_vpc_security_group_ingress_rule.ssh) == 0 &&
      aws_vpc_security_group_egress_rule.internet.security_group_id == output.instance_security_group_id &&
      aws_vpc_security_group_egress_rule.internet.cidr_ipv4 == "0.0.0.0/0" &&
      aws_vpc_security_group_egress_rule.internet.ip_protocol == "-1"
    )
    error_message = "The instance security group must belong to this VPC, allow outbound IPv4, and have no SSH ingress by default."
  }
}

run "private_shared_nat" {
  command = apply

  variables {
    network_mode         = "private"
    private_subnet_cidrs = ["10.42.101.0/24", "10.42.102.0/24"]
    subnet_index         = 1
    single_nat_gateway   = true
  }

  assert {
    condition = (
      output.instance_subnet_id == output.private_subnet_ids[1] &&
      output.instance_public_ip == null &&
      length(output.nat_gateway_ids) == 1 &&
      length(aws_vpc_security_group_ingress_rule.ssh) == 0
    )
    error_message = "Shared-NAT mode must select the second private subnet, expose no public address or SSH rule, and create one NAT gateway."
  }
}

run "private_nat_per_az" {
  command = apply

  variables {
    network_mode         = "private"
    private_subnet_cidrs = ["10.42.101.0/24", "10.42.102.0/24"]
    subnet_index         = 1
    single_nat_gateway   = false
  }

  assert {
    condition = (
      output.instance_subnet_id == output.private_subnet_ids[1] &&
      output.instance_public_ip == null &&
      length(distinct(output.nat_gateway_ids)) == length(var.availability_zones)
    )
    error_message = "Per-AZ mode must select the requested private subnet, expose no public address, and create a distinct NAT gateway per AZ."
  }
}

run "allow_only_requested_ssh_sources" {
  command = apply

  variables {
    key_name          = "example-admin-key"
    ssh_allowed_cidrs = ["203.0.113.10/32", "198.51.100.0/24"]
  }

  assert {
    condition = (
      toset(keys(aws_vpc_security_group_ingress_rule.ssh)) == var.ssh_allowed_cidrs &&
      alltrue([for cidr, rule in aws_vpc_security_group_ingress_rule.ssh :
        rule.security_group_id == output.instance_security_group_id &&
        rule.cidr_ipv4 == cidr && rule.ip_protocol == "tcp" &&
        rule.from_port == 22 && rule.to_port == 22
      ])
    )
    error_message = "Allow SSH only on TCP port 22 from the configured administrator CIDRs."
  }
}

run "reject_unknown_network_mode" {
  command = plan

  variables {
    network_mode         = "unknown"
    private_subnet_cidrs = ["10.42.101.0/24", "10.42.102.0/24"]
  }

  expect_failures = [var.network_mode]
}

run "reject_private_mode_without_subnets" {
  command = plan

  variables {
    network_mode         = "private"
    private_subnet_cidrs = []
  }

  expect_failures = [var.private_subnet_cidrs]
}

run "reject_world_open_ssh" {
  command = plan

  variables {
    key_name          = "example-admin-key"
    ssh_allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.ssh_allowed_cidrs]
}

run "reject_overbroad_ssh" {
  command = plan

  variables {
    key_name          = "example-admin-key"
    ssh_allowed_cidrs = ["0.0.0.0/1"]
  }

  expect_failures = [var.ssh_allowed_cidrs]
}

run "reject_ssh_without_key" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["203.0.113.10/32"]
  }

  expect_failures = [var.ssh_allowed_cidrs]
}

run "reject_empty_cost_center" {
  command = plan

  variables {
    tags = {
      CostCenter  = ""
      Environment = "test"
    }
  }

  expect_failures = [var.tags]
}
