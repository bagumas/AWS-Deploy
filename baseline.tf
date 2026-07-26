# Force global S3 public access block across the entire AWS account region
resource "aws_s3_account_public_access_block" "global_block" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Force EBS volume encryption by default for all new EC2 instances
resource "aws_ebs_encryption_by_default" "ebs_default" {
  enabled = true
}

