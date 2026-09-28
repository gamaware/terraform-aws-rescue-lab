# Thin root: environment settings only. Everything else lives in the module,
# so dev and prod cannot drift apart again.
locals {
  environment = "dev"
  name_prefix = "harbor"
}

module "storage" {
  source = "../../modules/app-storage"

  name_prefix = local.name_prefix
  environment = local.environment

  # Dev buckets hold test data only, so destroy may empty them.
  force_destroy = true

  tags = {
    Owner      = "platform-team"
    CostCenter = "cc-1002"
  }
}
