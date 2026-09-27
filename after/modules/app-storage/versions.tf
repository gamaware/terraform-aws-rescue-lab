terraform {
  # The force_destroy validation references another variable (1.9 or later);
  # the portfolio's common minimum is 1.11, where the S3 native lockfile the
  # environment roots use is generally available.
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
}
