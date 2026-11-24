# ok: slopguard.ruby.eval-user-input
ALLOWED_FORMULAS = { 'sum' => ->(a, b) { a + b }, 'max' => ->(a, b) { [a, b].max } }.freeze

def run_formula(name, a, b)
  fn = ALLOWED_FORMULAS.fetch(name) { raise ArgumentError, "Unknown formula" }
  fn.call(a, b)
end

# ok: slopguard.ruby.send-user-input
# Safe: dispatch table of lambdas — no send/public_send called with a variable.
SAFE_ACTIONS = {
  'approve' => ->(o) { o.approve },
  'reject'  => ->(o) { o.reject },
  'archive' => ->(o) { o.archive }
}.freeze

def call_action(obj, action_name)
  fn = SAFE_ACTIONS.fetch(action_name) { raise ArgumentError, "Unknown action" }
  fn.call(obj)
end
