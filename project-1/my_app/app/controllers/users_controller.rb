class UsersController < ApplicationController

  skip_before_filter :authenticate, only: [:new, :create]

  def index
    @users = User.all
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        log_in(@user)
        format.html { redirect_to user_images_path(current_user), notice: 'User was successfully created.' }
        format.json { render :show, status: :created, location: user_images_path(current_user) }
      else
        format.html { render :new }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_params
    params.require(:user).permit(:login, :password)
  end

end
