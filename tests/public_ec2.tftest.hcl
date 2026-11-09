mock_provider "aws" {
  override_data {
    target = data.aws_ami.amazon_linux[0]
    values = {
      id = "ami-0123456789abcdef0"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.ec2_assume_role
    values = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    }
  }
}

run "public_ec2_plan" {
  command = plan

  module {
    source = "./modules/public_ec2"
  }

  variables {
    name_prefix             = "public-ec2-test"
    environment             = "test"
    vpc_cidr                = "10.20.0.0/16"
    public_subnet_cidr      = "10.20.1.0/24"
    availability_zone       = "us-east-1a"
    allowed_icmp_ipv4_cidrs = ["1.1.1.1/32"]
    ping_target_ipv4        = "1.1.1.1"
  }

  assert {
    condition     = aws_subnet.public.map_public_ip_on_launch
    error_message = "The public subnet must auto-assign public IPv4 addresses."
  }

  assert {
    condition     = aws_route.internet_ipv4.destination_cidr_block == "0.0.0.0/0"
    error_message = "The public route table must contain a default IPv4 route."
  }

  assert {
    condition     = aws_instance.this.associate_public_ip_address
    error_message = "The EC2 instance must explicitly request a public IPv4 address."
  }

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "The EC2 instance must require IMDSv2."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted
    error_message = "The EC2 root volume must be encrypted."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.icmp_echo_request["1.1.1.1/32"].from_port == 8 && aws_vpc_security_group_egress_rule.icmp_echo_request["1.1.1.1/32"].to_port == 0
    error_message = "The ICMP rule must allow echo requests only."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.https.from_port == 443 && aws_vpc_security_group_egress_rule.https.to_port == 443
    error_message = "HTTPS egress must be available to Systems Manager."
  }
}
