# ok: slopguard.ruby.sql-string-interpolation
# Safe: array-syntax placeholder — ActiveRecord binds the value without interpolation.
def search_users(name)
  User.where('name = ?', name)
end

# Safe: hash syntax — ActiveRecord maps column to value securely.
def find_by_email(address)
  User.where(email: address).first
end
