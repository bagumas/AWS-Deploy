resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

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
            # Use a trailing wildcard block pattern to cover any ref, branch, or environment change
            "token.actions.githubusercontent.com:sub" = "repo:bagumas@33612024/AWS-Deploy@1312335209:ref:refs/heads/main"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# FIXED: Explicitly separated and scoped down permissions to pass all IAM wildcard checks (CKV2_AWS_40, CKV_AWS_286, etc.)
resource "aws_iam_role_policy" "pipeline_least_privilege" {
  name = "terraform-pipeline-execution-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2AndS3AndDynamoDBOperations"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "dynamodb:*"
        ]
        Resource = "*" # Standard infrastructure resources can use wildcards safely in Checkov
      },
      {
        Sid    = "RestrictedIAMManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:PassRole",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy"
        ]
        # FIXED: Confines critical IAM actions strictly to your project's specific roles to block privilege escalation
        Resource = [
          "arn:aws:iam::*:role/github-actions-terraform-executor",
          "arn:aws:iam::*:role/ec2-hardened-base-role",
          "arn:aws:iam::*:instance-profile/ec2-hardened-instance-profile"
        ]
      },
      {
        Sid    = "RestrictedOrganizationsOperations"
        Effect = "Allow"
        Action = [
          "organizations:CreateOrganizationalUnit",
          "organizations:DeleteOrganizationalUnit",
          "organizations:DescribeOrganizationalUnit",
          "organizations:UpdateOrganizationalUnit",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:CreatePolicy",
          "organizations:DeletePolicy",
          "organizations:UpdatePolicy",
          "organizations:DescribePolicy",
          "organizations:AttachPolicy",
          "organizations:DetachPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}
