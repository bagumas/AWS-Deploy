output "bucket_arn" {
  description = "ARN of the secure S3 bucket"
  value       = aws_s3_bucket.secure.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting the bucket"
  value       = aws_kms_key.bucket_key.arn
}
