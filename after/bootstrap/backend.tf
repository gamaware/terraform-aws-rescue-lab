# The bootstrap stack creates the state bucket, so its first apply cannot use
# it. Apply once with this file renamed to backend.tf.off, then rename it back
# and run terraform init -migrate-state (migration/README.md, step 1).
terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
