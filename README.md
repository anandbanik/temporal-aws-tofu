# Temporal on AWS Fargate

Modular Terraform/OpenTofu that deploys a self-hosted [Temporal](https://temporal.io) cluster to AWS
Fargate, along with the two custom Docker images it runs. There's no application code here — the
deployable artifacts are Terraform plans and container images.

## Architecture

`main.tf` wires four modules together in dependency order — `vpc` → `security_groups` → `postgres` →
`ecs_fargate` (named `temporal` in `main.tf`). Each module is self-contained, with its own
`main.tf` / `variables.tf` / `outputs.tf`.

- **`modules/vpc`** — public + private subnets across `az_count` AZs, with NAT gateway(s)
  (`single_nat_gateway` controls one shared NAT vs. one per AZ).
- **`modules/security_groups`** — least-privilege ingress for the ALB, ECS tasks, the frontend NLB,
  and RDS.
- **`modules/postgres`** — single RDS Postgres instance. The master password is generated with the
  `random` provider and stored in a Secrets Manager secret (`db_credentials`), along with the host,
  port, and database name. The password never appears as a Terraform output or in plaintext in any
  container's environment — ECS tasks read it via `secrets`/`valueFrom`.
- **`modules/ecs_fargate`** — the core of the deployment. One ECS cluster runs three things:
  1. **`temporal-dbsetup`** — a one-shot Fargate task (`admin-tools` image) that creates the
     `temporal` and `temporal_visibility` databases/schemas. It's launched imperatively by a
     `null_resource` `local-exec` provisioner that shells out to `aws ecs run-task` +
     `aws ecs wait tasks-stopped` (this requires the AWS CLI, with credentials and permissions beyond
     what the Terraform AWS provider itself needs, on the machine running `terraform apply`).
     `aws_ecs_service.server` depends on this task so the schema exists before the server starts.
  2. **`temporal-server`** (custom `server` image wrapping `temporalio/server`) — runs all Temporal
     services. The frontend gRPC endpoint is published two ways:
     - a private Cloud Map DNS namespace (`<name>.local`, service `temporal-frontend`) for clients
       that can resolve private DNS inside the VPC, e.g. the UI task and workers running on
       EC2/ECS/Lambda in the same VPC.
     - an NLB (`aws_lb.frontend`, TCP/`frontend_grpc_port`, target type `ip`) for clients that can't
       use Cloud Map. **This NLB is internet-facing** (`internal = false`, deployed in the public
       subnets) — ingress is restricted by the `nlb` security group to
       `frontend_nlb_ingress_cidrs`, but that variable defaults to `0.0.0.0/0` and the gRPC port has
       no auth/mTLS in front of it. Restrict this CIDR before deploying anything beyond a quick test.
  3. **`temporal-ui`** (upstream `temporalio/ui` image) — sits behind an internet-facing ALB (UI port
     only, default `8080`), and reaches the server over the internal Cloud Map DNS name.

  Both task definitions share one IAM execution role (scoped to `secretsmanager:GetSecretValue` on
  exactly the Postgres secret) and one task role. The Temporal server and UI tasks themselves run in
  private subnets with no public IPs.

- **`dockerImage/server`** — thin wrapper around `temporalio/server`. `scripts/entrypoint.sh` resolves
  `BIND_ON_IP` and `TEMPORAL_BROADCAST_ADDRESS` from ECS task metadata (falling back to hostname
  resolution) before starting `temporal-server`, since Fargate `awsvpc` tasks don't have a fixed
  advertise address known ahead of time. Dynamic config comes from
  `config/dynamicConfig/development-sql.yaml`.
- **`dockerImage/admin-tools`** — thin wrapper around `temporalio/admin-tools`;
  `scripts/setup-postgres.sh` runs `temporal-sql-tool` to create and migrate the `temporal` and
  `temporal_visibility` databases over TLS, then exits. Used only by the one-shot dbsetup task.

Docker images are built and pushed by GitHub Actions
(`.github/workflows/docker-server.yml`, `docker-admin-tools.yml`), not locally. Both build on every
push/PR touching their directory (multi-arch: `linux/amd64` + `linux/arm64`), and push to GHCR
(`ghcr.io/<repo>/server`, `ghcr.io/<repo>/admin-tools`) only on push to `main` (tagged `latest`) or on
a matching tag:

```bash
git tag server/v1.0.0        # triggers a tagged push of the server image
git tag admin-tools/v1.0.0   # triggers a tagged push of the admin-tools image
```

Image tags referenced in `modules/ecs_fargate/main.tf` are pinned manually and are **not**
auto-updated by these workflows — bump them deliberately after a new tag is pushed.

## Layout

```
.
├── main.tf                    # wires the modules together
├── variables.tf
├── outputs.tf
├── versions.tf                # Terraform/OpenTofu >= 1.5.0, aws ~> 5.0, random ~> 3.6
├── terraform.tfvars           # your local config (gitignored; not checked in)
├── modules/
│   ├── vpc/
│   ├── security_groups/
│   ├── postgres/
│   └── ecs_fargate/
├── dockerImage/
│   ├── server/                # wraps temporalio/server
│   └── admin-tools/            # wraps temporalio/admin-tools, used for one-shot db setup
└── .github/workflows/
    ├── docker-server.yml
    └── docker-admin-tools.yml
```

## Usage

Requires the AWS CLI (authenticated) in addition to Terraform/OpenTofu — the dbsetup provisioner and
`aws_ecs_service.server` depend on `aws ecs run-task`/`wait` succeeding wherever `apply` runs.

```bash
# create terraform.tfvars and set at minimum alb_ingress_cidrs / frontend_nlb_ingress_cidrs
terraform init
terraform validate
terraform plan
terraform apply
terraform fmt -recursive   # format before committing
```

Key variables (see `variables.tf` for the full list and defaults):

| Variable | Purpose |
| --- | --- |
| `aws_region` | Region to deploy into |
| `vpc_cidr`, `az_count`, `public_subnet_cidrs`, `private_subnet_cidrs` | VPC/subnet layout |
| `single_nat_gateway` | One shared NAT gateway (cheaper) vs. one per AZ (more resilient) |
| `alb_ingress_cidrs` | CIDRs allowed to reach the Temporal Web UI — **default `0.0.0.0/0`, restrict it** |
| `frontend_nlb_ingress_cidrs` | CIDRs allowed to reach the internet-facing frontend gRPC NLB — **default `0.0.0.0/0`, restrict it; this port has no auth in front of it** |
| `db_instance_class`, `db_allocated_storage`, `db_engine_version`, `db_multi_az` | RDS Postgres sizing |
| `temporal_version`, `temporal_ui_version` | Image tags for the server and UI tasks |
| `tags` | Tags applied to all resources |

After `terraform apply`, the relevant outputs are:

- `temporal_ui_url` — open in a browser to reach the Temporal Web UI
- `temporal_frontend_address` — Cloud Map `host:7233`, for workers that can resolve private DNS
  inside the VPC
- `temporal_frontend_nlb_address` — NLB `host:7233`, for workers that can't (note: this NLB is
  internet-facing, see above)
- `database_endpoint` / `database_secret_arn` — Postgres host and the Secrets Manager secret holding
  its master credentials

## Testing image changes locally

There are no unit tests for the Terraform itself; correctness is checked via
`terraform validate`/`plan` and by applying to a real AWS account. To test a Docker image change
before pushing:

```bash
docker build -t temporal-server-test dockerImage/server
docker build -t temporal-admin-tools-test dockerImage/admin-tools
```

## Notes / gotchas

- `alb_ingress_cidrs` and `frontend_nlb_ingress_cidrs` both default to `0.0.0.0/0` — restrict both
  before deploying anything beyond a quick test. The frontend NLB in particular has no auth/mTLS, so
  an open CIDR there exposes the Temporal frontend gRPC API to the internet.
- The database master password is never a Terraform output or container env var in plaintext; it's
  generated by the `random` provider and lives only in Secrets Manager, read by ECS via
  `secrets`/`valueFrom`.
- `single_nat_gateway = true` (default) uses one shared NAT gateway to minimize cost. Set it to
  `false` for one NAT gateway per AZ (more resilient, more expensive).
- `aws_ecs_service.server` and the `null_resource.run_temporal_admin` provisioner require the AWS CLI
  to be installed and authenticated wherever `terraform apply` runs — not just AWS provider
  credentials.
- Server/admin-tools image tags in `modules/ecs_fargate/main.tf` are pinned by hand; bump them after
  pushing a new tag via the `server/vX.Y.Z` / `admin-tools/vX.Y.Z` git tags described above.
