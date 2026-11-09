# VPC + EC2 root configuration

This root calls the existing `Adavid804/terraform-aws-vpc` and
`Adavid804/terraform-aws-ec2` modules. It adds the provider configuration,
security group, explicit module inputs, input validation, and root outputs.
Neither upstream module needs a change for the default internet connection.

The default is one EC2 instance in a public subnet with an auto-assigned public
IPv4 address. A security group permits outbound IPv4 traffic and has no inbound
rules unless restricted SSH is explicitly configured. The VPC module creates and
associates the route table and internet gateway. These are the pieces required
for [IPv4 internet access](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html).

```text
EC2 public IPv4 + root security group
  -> module.vpc.public_subnet_ids[subnet_index]
  -> public route table: 0.0.0.0/0
  -> internet gateway -> internet
```

## Files

| File | Purpose |
| --- | --- |
| `main.tf` | Calls both modules and connects subnet, security group, and public-IP mode |
| `security.tf` | Outbound IPv4 access and optional restricted SSH |
| `variables.tf` | Required settings, defaults, and invalid-combination checks |
| `outputs.tf` | Network, security-group, and instance outputs |
| `providers.tf`, `versions.tf` | AWS region and compatible Terraform/provider constraints |
| `.terraform.lock.hcl` | Root provider selection and checksums; commit this file |
| `terraform.tfvars.example` | Editable public configuration and private alternative |
| `backend.tf.example`, `state.s3.tfbackend.example` | Optional S3 backend and placeholder settings |
| `tests/connectivity.tftest.hcl` | Offline checks using a mocked AWS provider |
| `PREDEPLOYMENT.md` | Required decisions, source findings, and optional module additions |
| `VALIDATION.md` | Completed checks and limits of offline verification |

## Reviewed sources

Modules are pinned to the commits inspected on `main` on November 1, 2026:

- VPC: [`cec4cdacc954e5685823794df69c176fd934fd52`](https://github.com/Adavid804/terraform-aws-vpc/tree/cec4cdacc954e5685823794df69c176fd934fd52)
- EC2: [`8afd1f04e1aa185ecd00025691ad01c7efae2818`](https://github.com/Adavid804/terraform-aws-ec2/tree/8afd1f04e1aa185ecd00025691ad01c7efae2818)

Do not replace the pins with `ref=main` unless you intend module code to change
when initialization is refreshed. The root requires Terraform >=1.10 and <2.0
for optional native S3 state locking, and AWS provider 6.x. The supplied lockfile selects
AWS provider 6.71.0. Child modules allow Terraform >=1.5 and AWS provider >=5.0.

## Configure and review a deployment

Run the following from this directory with Terraform and Git installed:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. Set the target region, actual AZ names, resource name,
and your `CostCenter` and `Environment` tags. The example's region and address
ranges are examples, not values discovered from an AWS account. Review
`PREDEPLOYMENT.md` before using them. Prefer setting `ami_id` to a verified
regional x86_64 AMI to make instance plans repeatable.

Use your normal AWS credential/profile configuration; do not put credentials in
Terraform files. For a named profile in PowerShell, set `$env:AWS_PROFILE` to its
name. Then:

```powershell
terraform init
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan -out=review.tfplan
terraform show review.tfplan
```

The tests mock AWS and create no real resources. The plan command uses real AWS
credentials and reads account data. Review it in your intended account before
running `terraform apply review.tfplan`. No AWS plan or deployment was performed
when preparing this bundle. IAM permissions, account restrictions, AMI/key/profile
existence, regional capacity, and live connectivity still require account checks.

### Optional S3 state

A fresh checkout uses local state. To use S3 for a new deployment, choose your own private bucket before the first plan or apply. Enable S3 Block Public Access and bucket versioning, and limit access to the state and lock objects to the Terraform operators.

```powershell
Copy-Item backend.tf.example backend.local.tf
Copy-Item state.s3.tfbackend.example state.s3.tfbackend
```

Edit the bucket, key, and region in `state.s3.tfbackend`, then run `terraform init -backend-config=state.s3.tfbackend`. Git ignores both local copies. Use your AWS profile or role for credentials. The template requests encryption and native S3 locking. If the directory already manages infrastructure, back up its state and review Terraform's migration prompts before switching backends. [S3 backend reference](https://developer.hashicorp.com/terraform/language/backend/s3)

## Private instance alternative

Change these values together in `terraform.tfvars`:

```hcl
network_mode        = "private"
private_subnet_cidrs = ["10.42.101.0/24"]
single_nat_gateway  = true
```

The public subnet remains necessary for this module's public NAT gateway. The
instance receives no public IPv4 address and uses:

```text
EC2 private IPv4 + root security group
  -> module.vpc.private_subnet_ids[subnet_index]
  -> private route table: 0.0.0.0/0 -> NAT gateway + EIP
  -> public route table: 0.0.0.0/0 -> internet gateway -> internet
```

The root automatically enables NAT only in private mode. It requires nonempty
private subnets and matching public/private AZ counts, avoiding invalid indexing
in the current VPC module. For multiple AZs, list one public and one private CIDR
per AZ. `single_nat_gateway = false` creates a NAT gateway for each private
subnet in the corresponding public subnet/AZ. A single shared NAT is a dependency
on its AZ and may carry cross-AZ traffic; per-AZ NAT adds cost.

NAT permits connections initiated by the instance; it does not provide inbound
internet SSH or HTTP access. See the [AWS NAT gateway documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html).
EC2, public IPv4 addresses, NAT, data transfer, and enabled flow logs can incur charges.

## Administration and application traffic

No inbound rule is needed for response traffic because
[security groups are stateful](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html).
The default instance has internet egress but no configured interactive login path.

- For Session Manager, provide an existing `iam_instance_profile` **name** with
  appropriate SSM permissions and use an AMI with a running SSM agent. The caller
  also needs permission to start sessions. This root does not create that profile.
- For direct SSH in public mode, set both `key_name` and `ssh_allowed_cidrs` to
  an existing regional key pair and your actual administrator source CIDR(s), /24 through /32.
  The private key stays with you. The example `203.0.113.10/32` is not a usable source.
- HTTP/HTTPS ingress is not enabled by default. An internet-connected instance
  is not automatically a web server. Add only the application's required ports,
  allowed source ranges, and a running listener; see `PREDEPLOYMENT.md`.

## Validation performed

Run `terraform init -backend=false`, `terraform validate`, and `terraform test` in this directory to check the example without AWS credentials. See [validation results](VALIDATION.md) for the cases covered and the limits of the mocked tests.
