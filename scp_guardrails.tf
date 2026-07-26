# 1. Deny Leaving the Organization
resource "aws_organizations_policy" "deny_leave_org" {
  name        = "deny-leave-organization"
  description = "Prevent member accounts from leaving the AWS Organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyLeave"
      Effect   = "Deny"
      Action   = ["organizations:LeaveOrganization"]
      Resource = "*"
    }]
  })
}

# 2. Restrict Regions (Only allow us-east-1 and us-west-2)
resource "aws_organizations_policy" "restrict_regions" {
  name        = "restrict-aws-regions"
  description = "Disable all AWS regions except approved corporate compliance regions"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyUnapprovedRegions"
      Effect = "Deny"
      NotAction = [
        "iam:*", "organizations:*", "route53:*", "support:*", "cloudfront:*", "waf:*" # Global services must be excluded
      ]
      Resource = "*"
      Condition = {
        StringNotEquals = {
          "aws:RequestedRegion" = ["us-east-1", "us-west-2"] # Add your allowed regions here
        }
      }
    }]
  })
}

# 3. Protect Security Tools (CloudTrail, GuardDuty, AWS Config)
resource "aws_organizations_policy" "protect_security_tools" {
  name        = "protect-core-security-tools"
  description = "Prevent sub-accounts from disabling or deleting critical security monitoring tools"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ProtectSecurityServices"
      Effect = "Deny"
      Action = [
        "cloudtrail:DeleteTrail", "cloudtrail:StopLogging", "cloudtrail:UpdateTrail",
        "guardduty:DeleteDetector", "guardduty:DisassociateFromMasterAccount", "guardduty:UpdateDetector",
        "config:DeleteConfigurationRecorder", "config:StopConfigurationRecorder"
      ]
      Resource = "*"
    }]
  })
}


# Example: Attaching the Leave Org protection to a specific target account
resource "aws_organizations_policy_attachment" "attach_leave_protection" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = "328972548828" # REPLACE with your actual target AWS Member Account ID
}

# Example: Attaching the Region Restriction to an entire Organizational Unit (OU)
resource "aws_organizations_policy_attachment" "attach_region_restriction" {
  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = "ou-w5hy-kfaknvwz" # REPLACE with your actual target AWS OU ID
}
