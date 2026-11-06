# ok: slopguard.ruby.insecure-random
# Safe: SecureRandom uses the OS CSPRNG — suitable for tokens and session IDs.
def generate_token
  SecureRandom.hex(32)
end

# Safe: SecureRandom.uuid produces a cryptographically random identifier.
def generate_session_id
  SecureRandom.uuid
end
