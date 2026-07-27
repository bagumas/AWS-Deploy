# Secure S3 Storage Bucket — Service Catalog product module
# Secure-by-default: KMS encryption with rotation + explicit key policy,
# TLS 1.2+ enforced, all public access blocked, versioning + lifecycle enabled.

data "aws_caller_identity" "current" {}

#checkov:skip=CKV2_AWS_64:Key policy is defined below via aws_kms_key_policy resource
resource "aws_kms_key" "bucket_key" {
  description         = "KMS key for secure S3 bucket"
  enable_key_rotation = true
}

resource "aws_kms_key_policy" "bucket_key" {
  key_id = aws_kms_key.bucket_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "secure-s3-key-policy"
    Statement = [
      {
        Sid       = "EnableRootAccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowS3ServiceUse"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "secure" {
  #checkov:skip=CKV_AWS_18:Access logging requires a pre-existing central log bucket; consumers attach logging per their environment's logging standard
  #checkov:skip=CKV_AWS_144:Cross-region replication requires a destination bucket and replication role outside the scope of a single-bucket baseline product
  #checkov:skip=CKV2_AWS_62:Event notifications require a consumer (SQS/SNS/Lambda) which this baseline product does not prescribe
  bucket = var.bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.bucket_key.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secure" {
  bucket                  = aws_s3_bucket.secure.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.secure.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.secure.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.secure.arn,
          "${aws_s3_bucket.secure.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyOldTlsVersions"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.secure.arn,
          "${aws_s3_bucket.secure.arn}/*"
        ]
        Condition = {
          NumericLessThan = { "s3:TlsVersion" = 1.2 }
        }
      }
    ]
  })
}
