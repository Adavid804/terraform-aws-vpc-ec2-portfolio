terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "public_ec2_test" {
  source = "../../modules/public_ec2"

  name_prefix             = "public-ec2-test"
  environment             = "test"
  vpc_cidr                = "10.20.0.0/16"
  public_subnet_cidr      = "10.20.1.0/24"
  availability_zone       = "us-east-1a"
  allowed_icmp_ipv4_cidrs = ["1.1.1.1/32"]
  ping_target_ipv4        = "1.1.1.1"
}
