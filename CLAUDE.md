# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Terraform for per-team AWS dev environments (eu-west-2, account 493245399435), deployed by GitHub Actions through OIDC. GitHub repo: `pro-digital-uk/bravo-team-infra`. There is no application code; everything is Terraform plus one static `index.html`.

## Layout: three independent root stacks

There is no root module. Each folder below is its own Terraform root with its own backend state in the bucket `terraform-state-493245399435`:

| Folder | State key | Applied by | Contents |
|---|---|---|---|
| `team-alpha/` | `dev/alpha/terraform.tfstate` | CI | VPC, subnets, SGs, two EC2 instances (public + private), SSM instance role, key pair, public S3 static website |
| `team-bravo/` | `dev/bravo/terraform.tfstate` | CI | VPC and subnets only (so far) |
| `oidc-iam/` | `iam/github-oidc.tfstate` | **Locally only, never CI** | GitHub OIDC provider plus the plan and apply roles CI assumes |

`modules/` is empty; team folders duplicate code rather than share modules. Changes meant for "every team" must be made in each team folder.

## Commands

Run from inside a stack folder. Needs AWS credentials (SSO: `aws sso login --profile <profile>`); `validate` and `fmt` work without them.

```bash
terraform init
terraform fmt -check -recursive        # CI fails on any fmt diff
terraform validate
terraform plan  -var-file=dev.tfvars   # team-alpha needs a var file; team-bravo has defaults
terraform apply -var-file=dev.tfvars
terraform apply -target=<address>      # e.g. -target=aws_s3_bucket.main
```

Validate without touching the backend: `terraform init -backend=false && terraform validate`.

## Variables and tfvars

- `team-alpha` variables have **no defaults**; `team-bravo` variables all have defaults.
- `.gitignore` ignores `*.tfvars` with one exception: `team-*/dev.tfvars`. That file holds each team's non-secret values and is what CI passes with `-var-file` (only if it exists). Local-only files such as `team-alpha/team-alpha.tfvars` are ignored; `*.tfvars.sample` files are templates.
- Keep `dev.tfvars` in sync with what was applied locally, otherwise the CI plan will show unexpected changes.

## Naming is coupled to IAM permissions

Every resource name starts with `${var.team_name}-` (for example `alpha-vpc`, `alpha-ec2-ssm`, bucket `${team_name}-${bucket_name}-${project_name}`). The CI apply role in `oidc-iam/main.tf` only allows IAM roles, instance profiles and S3 buckets whose names start with a prefix in `managed_name_prefixes` (`oidc-iam/variables.tf`, currently `["alpha-", "bravo-"]`).

- Adding a team or changing `team_name` requires updating `managed_name_prefixes` and applying `oidc-iam` locally first, or CI applies fail with AccessDenied.
- Changing `team_name`, `project_name` or `bucket_name` renames resources, which forces destroy/recreate. `aws_s3_bucket.main` has no `force_destroy`, so replacing a non-empty bucket fails with `BucketNotEmpty`.
- The apply role's other permissions: state objects under `dev/*`, `ec2:*` limited to `var.aws_region`, CloudWatch log groups under `/vpc/*`, `iam:PassRole` to EC2 and VPC flow logs, and attaching only `AmazonSSMManagedInstanceCore`. A new resource type in a team stack (RDS, Lambda, CloudFront, etc.) also needs a new statement in `oidc-iam/main.tf`.
- The plan role is plain `ReadOnlyAccess`, so a plan can succeed while the matching apply is denied.

## CI (`.github/workflows/terraform.yml`)

- Matrix over `team-alpha` and `team-bravo`; each job runs in that folder. The matrix list is written twice (plan and apply jobs); a new team folder must be added to both, and to the `team` choice input.
- PRs to `main`: plan only. Push to `main`: plan, then apply, which waits for approval on the GitHub `dev` environment. Manual `workflow_dispatch` inputs: `action` (plan/apply/destroy), `team` (all or one), `confirm` (must be `destroy` for a destroy).
- Plans are uploaded as artifacts named `tfplan-<team>` and the apply job applies that saved plan.
- `concurrency: terraform-dev` with `cancel-in-progress: false`: a run waiting for `dev` approval holds the group, and GitHub cancels newer queued runs. If runs are being cancelled with no jobs, look for an old run in `waiting` status and approve or cancel it.
- If any matrix plan fails, apply is skipped for all teams.
- Secrets `AWS_PLAN_ROLE_ARN` and `AWS_APPLY_ROLE_ARN` come from the `oidc-iam` outputs.
- Terraform 1.5.7 in CI. `.terraform.lock.hcl` is gitignored (despite the comment at the bottom of `.gitignore`), so CI resolves `hashicorp/aws ~> 5.0` fresh each run.

## State locking

The S3 backends have no DynamoDB table or `use_lockfile`, so nothing stops two applies on the same stack at once. CI serialises through the concurrency group; avoid running a local apply while CI is applying the same team.

## team-alpha specifics

- S3 website: public-access block disabled, bucket policy grants public `s3:GetObject`, ACLs unused (`BucketOwnerPreferred`). Only `index.html` is uploaded (`aws_s3_object.main`, `content_type` hardcoded to `text/html`); extra site files need a `for_each` with per-extension content types.
- Subnet CIDRs are hardcoded in `locals.tf` and must sit inside `vpc_cidr_block`.
- NAT gateway resources are commented out in `vpc.tf`, so `enable_nat_gateway` currently does nothing and the private instance has no internet or SSM access.
- EC2 instances ignore AMI changes; roll to a new AMI with `terraform apply -replace=<address>`.
- All outputs in `output.tf` are commented out.
