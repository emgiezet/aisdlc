config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# NOTE: version placeholder — pin to verified release when tflint is added to tools.lock.json.
# The AWS ruleset is installed via `tflint --init` into the plugin cache; it is not bundled here.
plugin "aws" {
  enabled = true
  version = "0.40.0"   # pin to verified version when stage that adds tflint runs
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
