# 1. Register GitHub Identity Provider with both potential audiences
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://githubusercontent.com"
  
  # Includes both standard STS and the official GitHub token client ID
  client_id_list  = ["://amazonaws.com", "https://github.com"] 
  
  # Includes the standard thumbprint and the latest root authority thumbprints
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", 
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
    "15e4aa054ad40103b4431e1147a07c13a0da0593"
  ]
}

# 2. Reconfigure the execution role with a flexible wildcard rule for testing
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
            # Bypasses specific repo casing rules temporarily to isolate the connection issue
            "://githubusercontent.com:sub" = "repo:bagumas/*:*"
          }
          StringEquals = {
            # Ensures the token is coming directly from GitHub's official system
            "://githubusercontent.com:aud" = "://amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

