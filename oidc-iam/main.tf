data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  repo_sub   = var.github_sub_prefix

  managed_role_arns = [
    for p in var.managed_name_prefixes : "arn:aws:iam::${local.account_id}:role/${p}*"
  ]
  managed_instance_profile_arns = [
    for p in var.managed_name_prefixes : "arn:aws:iam::${local.account_id}:instance-profile/${p}*"
  ]
  managed_bucket_arns = flatten([
    for p in var.managed_name_prefixes : ["arn:aws:s3:::${p}*", "arn:aws:s3:::${p}*/*"]
  ])
}

# -----------------------------------------------------------------------------
# GitHub OIDC identity provider (one per account)
# -----------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS no longer checks these for GitHub, but older provider versions require them
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# -----------------------------------------------------------------------------
# Plan role - read-only. Used by pull requests and by pushes to main.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.repo_sub}:pull_request",
        "${local.repo_sub}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "github-actions-bravo-infra-plan"
  description          = "Read-only role for terraform plan in ${var.github_repo}"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# -----------------------------------------------------------------------------
# Apply role - can change infrastructure. Only jobs running in the GitHub
# environment (which should require reviewer approval) can assume it.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.repo_sub}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_apply" {
  name                 = "github-actions-bravo-infra-apply"
  description          = "Apply role for terraform in ${var.github_repo} (${var.github_environment})"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "apply" {
  # Terraform state
  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
  }

  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/${var.state_key_prefix}*"]
  }

  # VPC, subnets, NAT, security groups, flow logs, instances - all in the ec2 namespace
  statement {
    sid       = "Ec2AndVpcInRegion"
    actions   = ["ec2:*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  # VPC flow log groups
  statement {
    sid     = "FlowLogGroups"
    actions = ["logs:*"]
    resources = [
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/vpc/*",
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/vpc/*:*",
    ]
  }

  # Static website bucket - the bucket, its settings and its objects.
  # Scoped by name prefix, which excludes the Terraform state bucket.
  statement {
    sid       = "ManageStackBuckets"
    actions   = ["s3:*"]
    resources = local.managed_bucket_arns
  }

  statement {
    sid       = "DescribeLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # IAM roles the stack creates (flow logs role, EC2 SSM role).
  # Scoped by name prefix, which excludes the github-actions-* roles above.
  statement {
    sid = "ManageStackRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = local.managed_role_arns
  }

  # Only allow attaching the managed policies the stack actually uses
  statement {
    sid       = "AttachApprovedPolicies"
    actions   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = local.managed_role_arns

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
    }
  }

  statement {
    sid       = "PassStackRoles"
    actions   = ["iam:PassRole"]
    resources = local.managed_role_arns

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com", "vpc-flow-logs.amazonaws.com"]
    }
  }

  statement {
    sid = "ManageStackInstanceProfiles"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = local.managed_instance_profile_arns
  }
}

resource "aws_iam_role_policy" "github_apply" {
  name   = "terraform-apply-bravo-infra"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.apply.json
}
