# ruleid: slopguard.ruby.mass-assignment-without-permit
# Dangerous: raw params hash passed directly to create — any attribute settable.
def create
  @user = User.create(params)
end

# ruleid: slopguard.ruby.mass-assignment-without-permit
# Dangerous: params[:user] subscript still passes unfiltered user attributes.
def update
  @user = User.find(params[:id])
  @user.update(params[:user])
end
