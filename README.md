# bravo-team-infra

Terraform for each team's AWS dev environment, planned and applied by GitHub Actions using OIDC (no long-lived AWS keys).

- **Region:** eu-west-2
- **State bucket:** `terraform-state-493245399435`

## Repository layout

```
.
├── .github/workflows/terraform.yml   # CI: plan on PR, apply on merge to main
├── oidc-iam/                         # GitHub OIDC provider + CI roles (apply locally)
├── team-alpha/                       # Alpha's stack: VPC, EC2, S3 static website
├── team-bravo/                       # Bravo's stack: VPC
└── modules/                          # (empty)
```

Each folder is a separate Terraform stack with its own state:

| Stack | State key | Deployed by |
|---|---|---|
| `team-alpha` | `dev/alpha/terraform.tfstate` | GitHub Actions |
| `team-bravo` | `dev/bravo/terraform.tfstate` | GitHub Actions |
| `oidc-iam` | `iam/github-oidc.tfstate` | Locally, by an admin |

### team-alpha

- A VPC with public and private subnets in `eu-west-2a` and `eu-west-2b`.
- A public EC2 web server running Apache on port 80, and a private EC2 instance reachable only from the public one. Both use an SSM instance role.
- An S3 bucket configured for static website hosting, serving `index.html`.

### team-bravo

- A VPC with public and private subnets (`10.1.0.0/16`).

## Prerequisites

- Terraform 1.5 or later (CI uses 1.5.7)
- AWS CLI with access to account `493245399435`:
  ```bash
  aws sso login --profile <your-profile>
  ```

## Working locally

```bash
cd team-alpha
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=dev.tfvars
```

`team-alpha` has no variable defaults, so always pass a var file. `team-bravo` has defaults for everything.

### Variable files

| File | Committed? | Purpose |
|---|---|---|
| `team-*/dev.tfvars` | Yes | The values CI uses. Keep it non-secret. |
| `*.tfvars.sample` | Yes | Templates to copy |
| any other `*.tfvars` | No (gitignored) | Your local overrides |

## CI/CD

The workflow runs once for each team folder.

| Trigger | What happens |
|---|---|
| Pull request to `main` | `fmt`, `validate` and `plan` for each team; the plan appears in the job summary |
| Merge to `main` | Plan, then **apply** once someone approves the `dev` environment |
| Manual (Actions → Terraform → Run workflow) | Choose `plan`, `apply` or `destroy`, and `all` or one team. A destroy needs `confirm` set to `destroy`. |

Only one run can be active at a time. A run waiting for `dev` approval blocks later runs, and GitHub cancels them while they queue. Approve or cancel old waiting runs.

## First-time setup / changing CI permissions

`oidc-iam` creates the roles GitHub Actions assumes:

- **plan role:** read-only, used by PRs and by `main`.
- **apply role:** can change infrastructure, and is only usable from the `dev` environment.

CI never applies this stack itself. Apply it from your machine:

```bash
cd oidc-iam
terraform init
terraform apply
terraform output   # plan_role_arn and apply_role_arn
```

Then, in the GitHub repo settings:

1. Add the repository secrets `AWS_PLAN_ROLE_ARN` and `AWS_APPLY_ROLE_ARN` from the outputs.
2. Create the `dev` environment with required reviewers.

The apply role can only manage IAM roles, instance profiles and S3 buckets whose names start with a prefix in `managed_name_prefixes` (`alpha-`, `bravo-`). Every resource name starts with `<team_name>-`.

## Adding a team

1. Copy an existing team folder, for example `team-charlie/`.
2. In `backend.tf`, change the state `key` to `dev/charlie/terraform.tfstate`.
3. Set `team_name` and a VPC CIDR that doesn't overlap another team's. Update the subnet CIDRs in `locals.tf` to match.
4. Add `charlie-` to `managed_name_prefixes` in `oidc-iam/variables.tf`, then apply `oidc-iam` locally.
5. Add `team-charlie` to the workflow: both `matrix.team` lists and the `team` input options.
6. Commit a `team-charlie/dev.tfvars` if the stack has variables without defaults.

## Things to know

- **No state locking.** The S3 backend has no lock table, so don't run a local apply while CI is applying the same team.
- **Renaming replaces resources.** Changing `team_name`, `project_name` or `bucket_name` changes resource names, which destroys and recreates them. Empty the website bucket before renaming it, or the destroy fails.
- **The NAT gateway is disabled** (commented out in `vpc.tf`) to avoid about $32/month. Private instances have no internet access.
