output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN secret in GitHub"
  value       = aws_iam_role.github_plan.arn
}

output "apply_role_arn" {
  description = "Set as the AWS_APPLY_ROLE_ARN secret in GitHub"
  value       = aws_iam_role.github_apply.arn
}
