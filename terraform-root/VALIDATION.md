# Validation results

Checked on November 8, 2026, with Terraform 1.17.0 on Windows and the locked AWS provider 6.71.0. Terraform installed both Git modules at the revisions pinned in `main.tf`. The tests used the AWS mock provider.

| From this directory | Result |
| --- | --- |
| `terraform fmt -check -recursive` | Passed |
| `terraform init -backend=false -input=false -lockfile=readonly` | Passed |
| `terraform validate` | Passed |
| `terraform test` | 10 passed, 0 failed |

Four cases cover public placement, private placement through a shared NAT gateway, one NAT gateway per availability zone, and SSH restricted to the requested administrator addresses.

Six cases check input rejection for an unknown network mode, private mode without private subnets, SSH from a /0 or /1 network, SSH without a key, and an empty cost-center tag. The test cases are in [connectivity.tftest.hcl](tests/connectivity.tftest.hcl).

The four mock deployments were also inspected for EC2 subnet and security-group attachment, public-IP assignment, tagging, IMDSv2, root-volume encryption, and internet-gateway and NAT routing.

The repository-root example has its own mock test. Run `terraform test` in the repository root to check that configuration separately.

These checks used local state and simulated resources. Live AWS permissions, S3 policy and locking, flow-log delivery, and SSH or Session Manager connectivity require a separate deployment check.
