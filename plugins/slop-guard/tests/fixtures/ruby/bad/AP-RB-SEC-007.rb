# ruleid: slopguard.ruby.insecure-random
# Dangerous: Mersenne Twister output is predictable — not safe for tokens.
def generate_token
  rand(36**16).to_s(36)
end

# ruleid: slopguard.ruby.insecure-random
# Dangerous: Random.rand is equally predictable and should not seed security material.
def generate_session_id
  Random.rand(10**20).to_s
end
