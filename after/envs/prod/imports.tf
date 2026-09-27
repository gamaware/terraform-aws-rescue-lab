# The access log bucket was created by hand in the console and never managed
# (finding F9). The import block adopts it on the next apply; plan shows
# "1 to import" and no create for this address. Once applied, the block is a
# no-op and can stay as a record or be deleted.
import {
  to = module.storage.aws_s3_bucket.logs
  id = "${local.name_prefix}-${local.environment}-access-logs"
}
