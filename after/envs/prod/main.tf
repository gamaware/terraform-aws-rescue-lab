# Thin root: environment settings only. Everything else lives in the module,
# so dev and prod cannot drift apart again.
locals {
  environment = "prod"
  name_prefix = "harbor"
}

module "storage" {
  source = "../../modules/app-storage"

  name_prefix = local.name_prefix
  environment = local.environment

  tags = {
    Owner      = "platform-team"
    CostCenter = "cc-1001"
  }
}
