# ruleid: slopguard.ruby.sql-string-interpolation
# Dangerous: user-controlled value interpolated directly into SQL string.
def search_users(name)
  User.where("name = '#{name}'")
end

# ruleid: slopguard.ruby.sql-string-interpolation
# Dangerous: interpolated column name enables attacker to inject arbitrary SQL.
def filter_by(column, value)
  User.where("#{column} = '#{value}'")
end
