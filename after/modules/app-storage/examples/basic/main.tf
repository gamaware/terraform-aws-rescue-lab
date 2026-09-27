# Smallest working call of the module. The module tests reuse it as a fixture.

provider "aws" {
  region = var.region
}

module "storage" {
  source = "../.."

  name_prefix   = "example"
  environment   = "dev"
  force_destroy = true

  tags = {
    Owner      = "platform-team"
    CostCenter = "cc-0000"
  }
}
