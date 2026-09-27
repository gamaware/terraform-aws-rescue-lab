terraform {
  # The force_destroy validation references another variable (1.9 or later);
  # the environment roots need 1.10 for the S3 native lockfile.
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
}
