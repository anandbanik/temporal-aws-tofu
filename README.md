# Temporal on AWS Fargate

Modular Terraform that deploys [Temporal](https://temporal.io) to AWS:

- **VPC** — public + private subnets across multiple AZs, NAT gateway(s), route tables (`modules/vpc`)
- **Security groups** — ALB, ECS tasks, RDS with least-privilege ingress (`modules/security_groups`)
- **Postgres** — RDS for PostgreSQL, encrypted, credentials stored in Secrets Manager (`modules/postgres`)
- **ECS Fargate** — ECS cluster running the Temporal server (`temporalio/auto-setup`, which creates the
  schema and visibility database on first boot) and the Temporal Web UI behind an internet-facing ALB.
  The frontend gRPC endpoint is published via Cloud Map private DNS so SDK workers running inside the
  VPC can reach it directly (`modules/ecs_fargate`)

## Layout

```
.
├── main.tf              # wires the modules together
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars.example
└── modules/
    ├── vpc/
    ├── security_groups/
    ├── postgres/
    └── ecs_fargate/
```

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — at minimum restrict alb_ingress_cidrs

terraform init
terraform plan
terraform apply
```

After apply, Terraform prints:

- `temporal_ui_url` — open this in a browser to reach the Temporal Web UI
- `temporal_frontend_address` — the internal `host:7233` address that SDK workers running inside
  the VPC (e.g. on ECS, EC2, or via VPN/peering) should use to connect to the frontend service
- `database_secret_arn` — Secrets Manager secret containing the Postgres master credentials

## Notes

- The Temporal server and UI tasks run in private subnets with no public IPs; only the ALB is
  internet-facing, and only on the UI port (default `8080`).
- `alb_ingress_cidrs` defaults to `0.0.0.0/0` in `variables.tf` for convenience — set it to a
  restricted CIDR (VPN/office IP range) before deploying anything beyond a quick test.
- The database master password is generated with the `random` provider and stored only in
  Secrets Manager; the ECS task execution role is granted `secretsmanager:GetSecretValue`
  scoped to that single secret.
- `single_nat_gateway = true` (default) uses one shared NAT gateway to minimize cost. Set it to
  `false` for one NAT gateway per AZ (more resilient, more expensive).
# temporal-aws-tofu
