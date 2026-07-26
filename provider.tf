terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }



  # Configures Terraform to save data online instead of locally
  backend "s3" {
    bucket         = "sam-terraform-state-unique-bucket-name" # Matches step 1
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "sam-terraform-locks" # Matches step 1
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1" # Replace with your preferred region
}

