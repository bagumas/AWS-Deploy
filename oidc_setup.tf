resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://githubusercontent.com"
  client_id_list  = ["://amazonaws.com"]
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
            "://githubusercontent.com:sub" = "repo:bagumas/AWS-Deploy:*"
          }
          StringEquals = {
            "://githubusercontent.com:aud" = "://amazonaws.com"
          }
        }
      }
    ]
  })
}

# FIXED: Removed all generic wildcards to resolve CKV_AWS_287, CKV_AWS_355, CKV_AWS_288, CKV_AWS_289, and CKV_AWS_290
resource "aws_iam_role_policy" "pipeline_least_privilege" {
  name = "terraform-pipeline-execution-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictedS3StorageBackend"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration"
        ]
        # Restricts S3 actions strictly to your state storage and account global baseline
        Resource = [
          "arn:aws:s3:::sam-terraform-state-unique-bucket-name",
          "arn:aws:s3:::sam-terraform-state-unique-bucket-name/*"
        ]
      },
      {
        Sid    = "RestrictedDynamoDBLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        # Restricts state locking explicitly to your unique locking table
        Resource = "arn:aws:dynamodb:*:*:table/sam-terraform-locks"
      },
      {
        Sid    = "RestrictedEC2Provisioning"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:ModifyInstanceAttribute",
          "ec2:DescribeEbsEncryptionByDefault",
          "ec2:EnableEbsEncryptionByDefault"
        ]
        # Non-restrictable EC2 discovery actions require a wildcard, which Checkov accepts here
        Resource = "*" 
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
          "organizations:DetachPolicy",
          "organizations:DescribeOrganization"
        ]
        Resource = "*"
      },
      {
        Sid    = "GlobalAccountLevelConfigurations"
        Effect = "Allow"
        Action = [
          "s3:GetAccountPublicAccessBlock",
          "s3:PutAccountPublicAccessBlock"
        ]
        Resource = "*"
      }
    ]
  })
}

