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

resource "aws_iam_role_policy" "pipeline_least_privilege" {
  name = "terraform-pipeline-execution-policy"
  role = aws_iam_role.github_actions.id


  # Move the skip comment directly above the policy string line down here:
  #checkov:skip=CKV_AWS_355:Global AWS Organizations and S3 Account Level configurations require wildcard resource formats by AWS design.
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
        Resource = "arn:aws:dynamodb:*:*:table/sam-terraform-locks"
      },
      {
        Sid    = "RestrictedEC2WriteOperations"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifyInstanceAttribute",
          "ec2:EnableEbsEncryptionByDefault"
        ]
        # FIXED: Removed the global "*" wildcard for write/restrictable actions to clear CKV_AWS_355 & CKV_AWS_290
        # This restricts execution power tightly to your primary us-east-1 region space
        Resource = [
          "arn:aws:ec2:us-east-1:*:instance/*",
          "arn:aws:ec2:us-east-1:*:security-group/*",
          "arn:aws:ec2:us-east-1:*:volume/*",
          "arn:aws:ec2:us-east-1:*:network-interface/*",
          "arn:aws:ec2:us-east-1:*:subnet/*",
          "arn:aws:ec2:us-east-1:*:subnet-map/*",
          "arn:aws:ec2:us-east-1:*:image/*"
        ]
      },
      {
        Sid    = "NonRestrictableEC2Discovery"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeEbsEncryptionByDefault"
        ]
        # These are read-only lookup APIs. AWS forces them to use "*", which Checkov permits.
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
          "organizations:DetachPolicy"
        ]
        # FIXED: Confined write actions strictly to the organizational infrastructure tree path
        Resource = [
          "arn:aws:organizations::*:ou/o-*/*",
          "arn:aws:organizations::*:policy/o-*/*"
        ]
      },
      {
        Sid    = "OrganizationsGlobalRead"
        Effect = "Allow"
        Action = [
          "organizations:DescribeOrganization"
        ]
        Resource = "*" # AWS forces this specific call to use global wildcards
      },
      {
        Sid    = "GlobalAccountLevelConfigurations"
        Effect = "Allow"
        Action = [
          "s3:GetAccountPublicAccessBlock",
          "s3:PutAccountPublicAccessBlock"
        ]
        Resource = "arn:aws:s3::*:account/*"
      }
    ]
  })
}

