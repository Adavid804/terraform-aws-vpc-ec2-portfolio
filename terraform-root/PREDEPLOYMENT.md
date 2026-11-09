# Before deployment

The existing VPC and EC2 interfaces are sufficient for this root configuration. No upstream module change is required for the selected public-subnet internet path or the optional private-subnet NAT path. These findings are based on the pinned commits reviewed from `main`:

- VPC: [`cec4cdacc954e5685823794df69c176fd934fd52`](https://github.com/Adavid804/terraform-aws-vpc/tree/cec4cdacc954e5685823794df69c176fd934fd52).
- EC2: [`8afd1f04e1aa185ecd00025691ad01c7efae2818`](https://github.com/Adavid804/terraform-aws-ec2/tree/8afd1f04e1aa185ecd00025691ad01c7efae2818).

## Values and access to supply

| Item | Required action |
|---|---|
| Region, AZs, names | Set `aws_region`, actual `availability_zones` names in that region, and `name`. The example region/AZ is illustrative. |
| Tags | Replace the example `CostCenter` and `Owner`; choose `Environment`. Pass `tags` into the EC2 module explicitly: its `{}` default fails the validation requiring `CostCenter` and `Environment`. Provider default tags alone do not satisfy this validation. |
| CIDRs | Choose nonoverlapping subnet ranges inside the VPC CIDR, avoiding networks you will later connect. Use supported IPv4 prefix sizes (`/16` through `/28`). Root validation checks IPv4 syntax and subnet counts, but does not prove AWS size bounds, CIDR containment or absence of overlaps. See [AWS subnet sizing](https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html). |
| Image | Set a regional, accessible x86_64 `ami_id` for repeatable deployment, or intentionally accept discovery of the latest Amazon Linux 2023 image. Confirm the root volume is at least the image's snapshot size. The child module permits only `t3.micro`, `t3.small`, and `t3.medium`. |
| Administration | For Session Manager, supply an existing instance profile **name** with SSM permissions, an AMI with a running SSM agent, and operator permissions. Alternatively, in public mode supply both an existing regional `key_name` and real administrator CIDRs in `ssh_allowed_cidrs`. Neither method is enabled by the example defaults. |
| AWS access | Use credentials for the intended account with permission to create VPC/EC2 resources and, with flow logs enabled, CloudWatch Logs and IAM resources. Attaching an instance profile also requires appropriate `iam:PassRole` permission; see [EC2 role permissions](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html). |
| Custom KMS keys | If supplied, keys must exist in the region and permit the relevant use. A flow-log key must allow the regional CloudWatch Logs service; the EBS key must allow the EC2/EBS encryption workflow. Null values retain service-default encryption behavior. |
| State and live review | Configure an appropriate backend before shared use. Run and review an AWS-backed plan before apply. Account quotas, actual AMI/key/profile availability, IAM/KMS policies and connectivity have not been verified against your AWS account. |

EC2 interface evidence: [variables.tf](https://github.com/Adavid804/terraform-aws-ec2/blob/8afd1f04e1aa185ecd00025691ad01c7efae2818/variables.tf) and [main.tf](https://github.com/Adavid804/terraform-aws-ec2/blob/8afd1f04e1aa185ecd00025691ad01c7efae2818/main.tf). The module already requires IMDSv2 and encrypts the gp3 root volume.

## Network and security rules

- **Public mode:** EC2 uses `module.vpc.public_subnet_ids[subnet_index]`, explicitly requests a public IPv4 address, and uses the VPC module's public route table and `0.0.0.0/0` route to the internet gateway. No NAT gateway is created.
- **Private mode:** EC2 uses `module.vpc.private_subnet_ids[subnet_index]`, has no public IPv4 address, and sends outbound internet traffic through a NAT gateway in a public subnet. NAT does not provide an inbound internet connection. A shared NAT is placed in the first public subnet; for per-AZ NAT, set `single_nat_gateway = false` with corresponding public/private CIDRs for every AZ. NAT gateways and public IPv4 addresses incur charges.
- **Security group:** the root creates it in `module.vpc.vpc_id` and passes its ID to EC2. Explicit outbound IPv4 traffic is allowed to `0.0.0.0/0`. This intentionally supports general internet access; narrow protocols and destinations if the workload allows it. Return traffic is permitted by security-group state tracking, so an inbound rule is not needed for downloads.
- **Inbound:** no rules are created by default. Optional SSH is TCP 22 from the specified administrator CIDRs. HTTP/HTTPS ingress is not needed for outbound access; add TCP 80/443 only when hosting a service, with intended client CIDRs and a running listener/TLS setup. The configuration does not install a web server.
- **NACLs:** these modules do not create custom network ACLs; the new VPC's [default ACL allows traffic](https://docs.aws.amazon.com/vpc/latest/userguide/default-network-acl.html). If replacing it with a restrictive ACL, allow the workload traffic and return ephemeral ports in both directions as needed because ACLs are stateless.
- **Startup order:** root `module.ec2.depends_on` waits for the VPC module and SG rules. Subnet-ID references alone would not wait for route and association completion. This broad module dependency can defer the EC2 module's AMI lookup until apply when VPC resources change, which can cause a replacement to be planned because the AMI value is unknown. Pinning `ami_id` avoids that deferred discovery.

Routing evidence: [VPC main.tf](https://github.com/Adavid804/terraform-aws-vpc/blob/cec4cdacc954e5685823794df69c176fd934fd52/main.tf). AWS guidance: [internet gateways](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html), [NAT gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html), and [security-group basics](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html).

## Existing module gaps and proposed changes

These are upstream improvements to consider separately. They have not been applied to either repository.

| Finding | Concrete change / current root treatment |
|---|---|
| VPC permits NAT with no private subnets | Validate that NAT requires nonempty public and private subnet lists. With `single_nat_gateway = true`, the current module otherwise indexes a nonexistent private route table. This root rejects empty private subnets in private mode and disables NAT in public mode. |
| Per-subnet NAT can index missing public subnets | Validate public/private counts when `single_nat_gateway = false`. This root requires one public CIDR per AZ and, when provided, one private CIDR per AZ, preserving matching order. |
| `azs` description claims names or IDs | Change the description to AZ names, or explicitly implement `availability_zone_id` support. The current resource assigns `availability_zone`; this root accepts standard AZ names. |
| `nat_gateway_ids` description says EIP allocation IDs | Change the description to "IDs of NAT gateways". The value is already `aws_nat_gateway.this[*].id`. |
| Flow-log delivery role policy is not an explicit dependency | Add `depends_on = [aws_iam_role_policy.flow_log]` inside `aws_flow_log.this` so role permissions are attached before flow-log creation. Review its broad `resources = ["*"]` policy separately if least-privilege log permissions are required. |
| EC2 generated docs mark `tags` optional | Align the input default/validation and regenerate docs, or clearly document the effective requirement. The root supplies and validates the required nonempty tags. |
| No EC2 `user_data` interface | Only needed for bootstrapping. Add the inputs and resource forwarding shown below if a startup script is required. |

Sources: [VPC variables](https://github.com/Adavid804/terraform-aws-vpc/blob/cec4cdacc954e5685823794df69c176fd934fd52/variables.tf), [VPC outputs](https://github.com/Adavid804/terraform-aws-vpc/blob/cec4cdacc954e5685823794df69c176fd934fd52/outputs.tf), [EC2 generated docs](https://github.com/Adavid804/terraform-aws-ec2/blob/8afd1f04e1aa185ecd00025691ad01c7efae2818/README.md).

### Optional diagnostic outputs

All required connection outputs already exist. The EC2 output names are `instance_public_ip` and `instance_private_ip`, not `public_ip` and `private_ip`. The root re-exports these plus instance IDs, selected subnet, security group, VPC, subnet lists, IGW and NAT IDs.

If operational diagnostics need more detail, append the following to **terraform-aws-vpc/outputs.tf**:

```hcl
output "public_route_table_ids" {
  description = "IDs of public route tables"
  value       = aws_route_table.public[*].id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "nat_public_ips" {
  description = "Public IPv4 addresses used by NAT gateways"
  value       = aws_eip.nat[*].public_ip
}

output "nat_eip_allocation_ids" {
  description = "Allocation IDs of Elastic IPs used by NAT gateways"
  value       = aws_eip.nat[*].id
}
```

Append to **terraform-aws-ec2/outputs.tf** if a DNS name is useful:

```hcl
output "instance_public_dns" {
  description = "Public DNS name, when a public address and VPC DNS hostnames are enabled"
  value       = aws_instance.this.public_dns
}
```

### Optional startup-script interface

Add to **terraform-aws-ec2/variables.tf** only if bootstrapping is required:

```hcl
variable "user_data" {
  description = "Optional startup script; do not include secrets"
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Replace the instance when startup data changes"
  type        = bool
  default     = true
}
```

Add inside the existing `aws_instance.this` block:

```hcl
user_data                   = var.user_data
user_data_replace_on_change = var.user_data_replace_on_change
```

Then expose and forward the chosen script from the root. After any upstream edit, run that repository's documented checks, regenerate its Terraform documentation, and update the root's pinned module commit to the reviewed new revision. The current root does not reference any of these optional additions.
