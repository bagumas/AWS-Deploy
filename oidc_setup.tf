# 1. Register GitHub as a trusted Identity Provider inside AWS
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com" # Corrected URL
  client_id_list  = ["sts.amazonaws.com"]                         # Corrected official audience
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"] # Current trusted thumbprints
}

# 2. Create the execution role that GitHub Actions will temporarily assume
resource "aws_iam_role" "github_actions" {
  name = "github-actions-terraform-executor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            # Strictly locks down access to ONLY your specific GitHub user and repository name
            "token.actions.githubusercontent.com:sub" = "repo:bagumas/AWS-Deploy:*"
          }
        }
      }
    ]
  })
}

# 3. Give this role Admin permissions so it can manage your landing zone architecture
resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Output the unique Role ARN so you can drop it into your workflow file
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "Copy this ARN value into your GitHub workflow file."
}

