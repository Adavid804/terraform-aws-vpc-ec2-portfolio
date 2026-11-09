# AWS VPC and EC2 networking with Terraform

This repository contains two independently runnable Terraform examples.

- **Repository root.** Run an outbound connectivity check from a public EC2 instance. The local module creates a VPC, public subnet, internet gateway, default route, and a security group with no inbound rules. Session Manager provides administrative access.
- **[Public or private EC2 deployment](terraform-root/README.md).** Compose two pinned modules to place an instance in a public subnet or behind a NAT gateway. This example allows outbound IPv4 traffic. SSH is off by default. It includes an optional S3 state template and mocked connectivity tests.

To try either example without AWS credentials, use Terraform 1.10 or later and run `terraform init -backend=false`, `terraform validate`, and `terraform test` from that example's directory. The tests use a mocked AWS provider. The deployment walkthrough below covers the repository-root example.

The instance can send ICMP echo requests to an explicitly allowed public IPv4 CIDR. By default, it pings `1.1.1.1` once at first boot and writes the result to `/var/log/internet-connectivity-test.log`.

## Architecture and connectivity path

```text
Operator
   |  AWS Systems Manager Session Manager (no inbound SSH)
   v
AWS SSM public endpoints <--- HTTPS 443 egress
                              |
Internet <--- Internet Gateway <--- public route table <--- public subnet
                                                               |
                                                               +--- EC2 + public IPv4
                                                                    |
                                                                    +--- ICMP echo request to 1.1.1.1/32
```

The security group has no ingress rules. Its egress is limited to:

- ICMP echo requests (type 8, code 0) to `allowed_icmp_ipv4_cidrs`.
- TCP 443 to the internet for the SSM agent and HTTPS package endpoints.

Security groups are stateful, so replies to allowed outbound traffic are automatically permitted. The module intentionally leaves the VPC's default network ACL in place; its default allow rules provide the required return path. If you replace it with a custom network ACL, allow the outbound request and the corresponding inbound ephemeral return traffic.

## Repository layout

```text
.
|-- main.tf                         # Calls the reusable module
|-- providers.tf                    # AWS provider configuration
|-- variables.tf                    # Root inputs
|-- outputs.tf                      # Root outputs and SSM command
|-- versions.tf                     # Terraform/provider constraints
|-- terraform.tfvars.example        # Non-secret example values
|-- modules/public_ec2/             # Reusable VPC + public EC2 module
|-- terraform-root/                 # Independent public/private EC2 example
`-- tests/                          # Mock test and standalone validation fixture
```

## Deployment plan

1. Confirm the target AWS account, Region, CIDRs, naming, and expected cost.
2. Authenticate locally with an AWS role or other short-lived credentials. Do not put credentials in Terraform files or variable files.
3. Copy `terraform.tfvars.example` to `terraform.tfvars` and adjust values. Keep the ping target inside one of `allowed_icmp_ipv4_cidrs`.
4. Format, initialize, validate, and create a saved plan.
5. Review the plan for the expected VPC, route, IAM, security-group, and EC2 changes.
6. Run `terraform apply tfplan` only after explicit approval to create AWS resources.
7. Wait for the instance to appear as `Online` in Systems Manager, then test the first-boot log or run another ping through Session Manager.
8. Run `terraform destroy` when the environment is no longer needed, after reviewing and approving the destroy plan.

## Prerequisites

- Terraform `>= 1.5.0, < 2.0.0`.
- AWS provider `>= 5.0, < 7.0`; the dependency lock file pins the selected build.
- AWS CLI v2 and the Session Manager plugin for shell access.
- AWS credentials authorized to manage the VPC, EC2, security-group, route, IAM role, IAM instance profile, and policy-attachment resources in this stack.

The configuration does not contain or request long-lived AWS access keys.

## Inputs

| Name | Default | Purpose |
| --- | --- | --- |
| `aws_region` | `us-east-1` | Deployment Region |
| `name_prefix` | `public-ec2` | Resource names and Name tags |
| `environment` | `dev` | Environment tag |
| `vpc_cidr` | `10.0.0.0/16` | VPC IPv4 CIDR |
| `public_subnet_cidr` | `10.0.1.0/24` | Public-subnet IPv4 CIDR |
| `availability_zone` | `null` | Optional AZ; AWS selects one when omitted |
| `instance_type` | `t3.micro` | EC2 instance type |
| `ami_id` | `null` | Optional AMI override; otherwise latest Amazon Linux 2023 x86_64 |
| `root_volume_size` | `8` | Encrypted gp3 root volume size in GiB |
| `allowed_icmp_ipv4_cidrs` | `["1.1.1.1/32"]` | ICMP echo-request destinations |
| `ping_target_ipv4` | `1.1.1.1` | First-boot ping target |
| `tags` | `{}` | Additional resource tags |

See `modules/public_ec2/README.md` for the module interface and outputs.

## Format, validate, and plan

PowerShell:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform fmt -recursive
terraform init
terraform validate
terraform fmt -recursive -check
terraform plan -out=tfplan
```

Review `terraform plan` output carefully. To deploy only after approval:

```powershell
terraform apply tfplan
```

No Terraform state backend is configured because backend selection is organization-specific. For shared use, configure a remote backend with encryption, locking, versioning, and tightly scoped access before deployment.

## Test internet connectivity

An auto-assigned public IPv4 address, the public route, Internet Gateway, security-group egress, and default network ACL are all required for the outbound ping path. The instance is not configured to answer unsolicited pings from the internet.

After apply, pass the region and instance ID to the AWS CLI:

```powershell
$region = terraform output -raw aws_region
$instanceId = terraform output -raw instance_id
aws ssm start-session --region $region --target $instanceId
```

From the Session Manager shell:

```bash
sudo cat /var/log/internet-connectivity-test.log
ping -c 4 1.1.1.1
```

If you changed `ping_target_ipv4`, use that address in the manual test. If the instance is not `Online` in Systems Manager, verify its IAM instance profile, HTTPS egress, public IPv4 address, subnet route-table association, and SSM Agent status.

## Security considerations

- There is no inbound security-group rule, SSH key, or TCP 22 exposure. Administration uses SSM Session Manager.
- The instance profile attaches only `AmazonSSMManagedInstanceCore`; add workload permissions separately and scope them to the exact resources required.
- IMDSv2 is required, instance metadata tags are disabled, and the root EBS volume is encrypted.
- ICMP egress defaults to a single `/32`, not the whole internet. Keep `ping_target_ipv4` within the configured allowed CIDRs.
- HTTPS egress is broad because the public SSM and package endpoints vary by Region. For stronger egress controls, use private SSM interface endpoints, a controlled package mirror, or an egress proxy/firewall.
- User data contains no secrets. Store secrets in Secrets Manager or SSM Parameter Store and grant narrowly scoped read access if the workload later needs them.
- Enable CloudTrail and encrypted Session Manager session logging for production auditability. Restrict who can start sessions or run commands.
- The public IPv4 address makes the instance internet-routable, but the no-ingress security group blocks unsolicited connections. A private-subnet design with VPC endpoints is preferable when direct internet egress is not a requirement.

## Cost considerations

The main chargeable items are EC2 runtime, the gp3 root volume, the in-use public IPv4 address, and any data transfer or optional logging. This design avoids a NAT Gateway and does not allocate an Elastic IP. The default T3 instance uses standard CPU credits to avoid unlimited-mode surplus-credit charges, at the cost of throttling after credits are exhausted. The auto-assigned public IPv4 address can change after stop/start.

Review current AWS pricing for the selected Region and destroy the stack when it is no longer needed:

```powershell
terraform plan -destroy
# After reviewing and approving the destroy:
terraform destroy
```
