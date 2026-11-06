# ok: slopguard.ruby.mass-assignment-without-permit
# Safe: strong parameters — only explicitly permitted attributes are accepted.
def user_params
  params.require(:user).permit(:name, :email, :bio)
end

def create
  @user = User.create(user_params)
end

def update
  @user = User.find(params[:id])
  @user.update(user_params)
end
