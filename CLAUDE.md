# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Modular Terraform (OpenTofu/Terraform >= 1.5.0) that deploys a self-hosted [Temporal](https://temporal.io)
cluster to AWS Fargate, plus the two custom Docker images it runs. There is no application code — the
"build" artifacts are Terraform plans and container images.

## Commands

OpenTofu (run from repo root, `temporal-aws-tofu/`):

```bash
# first-time setup: create terraform.tfvars and set at minimum alb_ingress_cidrs and
# frontend_nlb_ingress_cidrs (both default to 0.0.0.0/0 — see "Things to watch for" below)
tofu init
tofu validate
tofu plan
tofu apply
tofu fmt -recursive                       # format before committing
```

There are no unit tests; correctness is checked via `tofu validate`/`plan` and by applying to a
real AWS account.

Docker images (`dockerImage/server` and `dockerImage/admin-tools`) are built and pushed by GitHub
Actions (`.github/workflows/docker-server.yml`, `docker-admin-tools.yml`), not locally. They build on
every push/PR touching their directory, and push to GHCR (`ghcr.io/<repo>/server`,
`ghcr.io/<repo>/admin-tools`) only on push to `main` or on a matching tag:

```bash
git tag server/v1.0.0        # triggers a tagged push of the server image
git tag admin-tools/v1.0.0   # triggers a tagged push of the admin-tools image
```

To test an image change locally before pushing:

```bash
docker build -t temporal-server-test dockerImage/server
docker build -t temporal-admin-tools-test dockerImage/admin-tools
```

## Architecture

`main.tf` wires four modules together in dependency order — `vpc` → `security_groups` → `postgres` →
`ecs_fargate` (named `temporal` in main.tf). Each module is self-contained with its own
`main.tf`/`variables.tf`/`outputs.tf`; there's no shared state between them except what's passed
explicitly as module inputs/outputs.

- **`modules/vpc`** — public + private subnets across `az_count` AZs, NAT gateway(s) (`single_nat_gateway`
  controls one-shared-NAT vs one-per-AZ).
- **`modules/security_groups`** — least-privilege ingress for ALB, ECS tasks, the frontend NLB, and RDS.
- **`modules/postgres`** — single RDS Postgres instance. Generates the master password with the
  `random` provider and writes it (plus host/port/db name) to a Secrets Manager secret
  (`db_credentials`) — the password never appears in Terraform state as plaintext output or in any
  container's environment variables directly; ECS reads it via `secrets`/`valueFrom`.
- **`modules/ecs_fargate`** — the core of the deployment. One ECS cluster runs three things:
  1. **`temporal-dbsetup`** — a one-shot Fargate task (`admin-tools` image) that creates the `temporal`
     and `temporal_visibility` databases/schemas. It's launched imperatively via a `null_resource`
     `local-exec` provisioner that shells out to `aws ecs run-task` + `aws ecs wait tasks-stopped`
     (this requires the AWS CLI on the machine running `tofu apply`, with credentials and
     permissions beyond what the Terraform AWS provider itself needs). `aws_ecs_service.server`
     depends on this resource so the schema exists before the server starts.
  2. **`temporal-server`** (`server` image, wraps `temporalio/server`) — runs all Temporal services.
     Registered two ways for frontend gRPC access:
     - a private Cloud Map DNS namespace (`<name>.local`) as `temporal-frontend`, internal-only, for
       clients that can resolve private DNS in this VPC (e.g. the UI task).
     - `aws_lb.frontend` (TCP/`frontend_grpc_port`, target type `ip`), for clients that can't use Cloud
       Map. **This NLB is internet-facing** (`internal = false`, deployed in the public subnets), not
       internal — ingress is restricted by the `nlb` security group to `frontend_nlb_ingress_cidrs`,
       but that variable defaults to `0.0.0.0/0` and the gRPC port has no auth/mTLS in front of it.
       Treat tightening this CIDR as a prerequisite for any non-throwaway deployment.
  3. **`temporal-ui`** (upstream `temporalio/ui` image) — sits behind an internet-facing ALB
     (UI port only, default `8080`); reaches the server over the same internal Cloud Map DNS name.
  Both task definitions share one IAM execution role (scoped to `secretsmanager:GetSecretValue` on
  exactly the Postgres secret) and one task role.
- **`dockerImage/server`** — thin wrapper around `temporalio/server`. `scripts/entrypoint.sh` resolves
  `BIND_ON_IP` and `TEMPORAL_BROADCAST_ADDRESS` from ECS task metadata (falling back to hostname
  resolution) before starting `temporal-server`, since Fargate `awsvpc` tasks don't have a fixed
  advertise address known ahead of time. Dynamic config comes from
  `config/dynamicConfig/development-sql.yaml`.
- **`dockerImage/admin-tools`** — thin wrapper around `temporalio/admin-tools`;
  `scripts/setup-postgres.sh` runs `temporal-sql-tool` to create+migrate the `temporal` and
  `temporal_visibility` databases over TLS, then exits (used only by the one-shot dbsetup task).

After `tofu apply`, the important outputs are `temporal_ui_url`, `temporal_frontend_address`
(Cloud Map `host:7233`, for workers that can resolve VPC private DNS),
`temporal_frontend_nlb_address` (NLB `host:7233`, for workers that can't), and `database_secret_arn`.

## Things to watch for when changing this repo

- `alb_ingress_cidrs` and `frontend_nlb_ingress_cidrs` both default to `0.0.0.0/0` — don't widen
  either further; if anything, prompt for restricting them. The NLB one matters more: it fronts the
  internet-facing frontend gRPC port, which has no auth/mTLS of its own.
- The Postgres password is intentionally never a Terraform output or container env var in plaintext —
  preserve the Secrets Manager indirection if you touch `modules/postgres` or the task definitions'
  `secrets` blocks.
- Image tags in `modules/ecs_fargate/main.tf` (`ghcr.io/.../server:vX`, `.../admin-tools:vX`) are pinned
  manually and are *not* auto-updated by the GitHub Actions workflows — bump them deliberately after a
  new image tag is pushed.
- `aws_ecs_service.server` and the `null_resource.run_temporal_admin` provisioner depend on the AWS CLI
  being available and authenticated wherever `tofu apply` runs (not just the Terraform AWS
  provider credentials).
