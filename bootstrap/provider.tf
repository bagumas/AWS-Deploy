terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "sam-terraform-state-unique-bucket-name"
    key            = "bootstrap/terraform.tfstate"   # separate key = separate state
    region         = "us-east-1"
    dynamodb_table = "sam-terraform-locks"
  }
}

provider "aws" {
  region = "us-east-1"
}
