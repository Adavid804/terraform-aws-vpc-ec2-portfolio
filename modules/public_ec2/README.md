# `public_ec2` module

Creates a VPC, one public subnet, an Internet Gateway, a public route table and association, a no-ingress security group, an SSM instance profile, and one EC2 instance with an auto-assigned public IPv4 address.

The module is intentionally small and reusable. It does not configure a Terraform provider or backend; the calling root module owns both.

## Example

```hcl
module "public_ec2" {
  source = "./modules/public_ec2"

  name_prefix             = "demo"
  environment             = "dev"
  vpc_cidr                = "10.0.0.0/16"
  public_subnet_cidr      = "10.0.1.0/24"
  instance_type           = "t3.micro"
  allowed_icmp_ipv4_cidrs = ["1.1.1.1/32"]
  ping_target_ipv4        = "1.1.1.1"

  tags = {
    Owner = "platform-team"
  }
}
```

## Inputs

| Name | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `name_prefix` | `string` | n/a | yes | Prefix for names and Name tags |
| `environment` | `string` | `dev` | no | Environment tag |
| `vpc_cidr` | `string` | n/a | yes | VPC IPv4 CIDR |
| `public_subnet_cidr` | `string` | n/a | yes | Public-subnet IPv4 CIDR |
| `availability_zone` | `string` | `null` | no | Optional AZ |
| `instance_type` | `string` | `t3.micro` | no | EC2 instance type |
| `ami_id` | `string` | `null` | no | AMI override; default discovers Amazon Linux 2023 x86_64 |
| `root_volume_size` | `number` | `8` | no | Encrypted gp3 root volume size in GiB |
| `allowed_icmp_ipv4_cidrs` | `list(string)` | `["1.1.1.1/32"]` | no | ICMP echo-request destinations |
| `ping_target_ipv4` | `string` | `1.1.1.1` | no | First-boot ping target |
| `tags` | `map(string)` | `{}` | no | Additional tags |

When supplying a custom or Arm-based instance type, also supply a compatible `ami_id`. Keep `ping_target_ipv4` inside one of `allowed_icmp_ipv4_cidrs`.

## Outputs

| Name | Description |
| --- | --- |
| `vpc_id` | VPC ID |
| `public_subnet_id` | Public-subnet ID |
| `internet_gateway_id` | Internet Gateway ID |
| `public_route_table_id` | Public route-table ID |
| `security_group_id` | Instance security-group ID |
| `instance_profile_name` | SSM instance-profile name |
| `instance_id` | EC2 instance ID |
| `instance_public_ipv4` | Auto-assigned public IPv4 address |
| `instance_private_ipv4` | Private IPv4 address |

## Operational notes

- No inbound rules are created; use Session Manager instead of SSH.
- ICMP egress permits only echo request type 8/code 0 to the configured CIDRs.
- HTTPS egress is required for public SSM endpoints.
- The module uses the VPC default network ACL. Custom network ACLs must allow requests and return traffic.
- The first-boot ping is a smoke test and logs its result even when the target does not reply; deployment success should not depend on a third-party ping endpoint.
