# ==============================================================================
# 1. DATA SOURCES & GLOBAL SETTINGS
# ==============================================================================

data "aws_organizations_organization" "current" {}

resource "aws_servicecatalog_portfolio" "platform_portfolio" {
  name          = "Enterprise Core Infrastructure"
  description   = "Approved secure-by-default infrastructure baselines."
  provider_name = "Cloud Platform Team"
}

# ==============================================================================
# 2. FIXED: PRODUCT WITH EXTERNAL PRODUCT ENGINE TYPE
# ==============================================================================

resource "aws_servicecatalog_product" "secure_s3" {
  name  = "Secure S3 Storage Bucket"
  owner = "Platform Security Team"
  type  = "EXTERNAL" # FIXED: Replaced TERRAFORM_OPEN_SOURCE with EXTERNAL

  provisioning_artifact_parameters {
    name         = "v1.0.0"
    description  = "Initial secure S3 baseline with enforced KMS and TLS 1.2"
    type         = "EXTERNAL" # FIXED: Replaced TERRAFORM_OPEN_SOURCE with EXTERNAL
    template_url = "https://service-catalog-assets-266408865927.s3.us-east-1.amazonaws.com/products/secure-s3-v1.0.0.tar.gz"

    # FIXED: Instructs AWS to bypass CloudFormation parsing for Terraform archives
    disable_template_validation = true
  }
}

resource "aws_servicecatalog_product_portfolio_association" "link" {
  portfolio_id = aws_servicecatalog_portfolio.platform_portfolio.id
  product_id   = aws_servicecatalog_product.secure_s3.id
}

# ==============================================================================
# 3. CONSTRAINTS & DISTRIBUTION
# ==============================================================================

resource "aws_iam_role" "sc_launch_role" {
  name = "ServiceCatalogLaunchRole-SecureS3"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "servicecatalog.amazonaws.com" } # FIXED: Cleared the malformed protocol string
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_servicecatalog_constraint" "launch_constraint" {
  portfolio_id = aws_servicecatalog_portfolio.platform_portfolio.id
  product_id   = aws_servicecatalog_product.secure_s3.id
  type         = "LAUNCH"
  parameters   = jsonencode({ RoleArn = aws_iam_role.sc_launch_role.arn })
}

resource "aws_servicecatalog_portfolio_share" "org_share" {
  portfolio_id      = aws_servicecatalog_portfolio.platform_portfolio.id
  principal_id      = data.aws_organizations_organization.current.arn
  type              = "ORGANIZATION"
  share_tag_options = false
}

