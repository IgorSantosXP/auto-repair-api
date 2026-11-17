terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "auto-repair-tfstate-814623398856"
    key          = "services/os/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
