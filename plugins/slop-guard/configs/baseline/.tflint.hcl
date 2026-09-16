config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# The aws plugin block is commented out. It will be enabled by the stage that pins tflint
# in tools.lock.json and verifies the ruleset version. The spec (§6.6) contained a placeholder
# "X.Y.Z" — do not activate this block until a verified version is committed.
#
# plugin "aws" {
#   enabled = true
#   version = "X.Y.Z"   # pin to verified release when tflint is added to tools.lock.json
#   source  = "github.com/terraform-linters/tflint-ruleset-aws"
# }
