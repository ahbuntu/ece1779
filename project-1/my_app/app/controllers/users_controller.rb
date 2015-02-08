class UsersController < ApplicationController

  skip_before_filter :authenticate, only: [:new, :create]
  before_filter :validate_current_user, except: [:new, :create]

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
        format.html { redirect_to @user, notice: 'User was successfully created.' }
        format.json { render :show, status: :created, location: @user }
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

  def validate_current_user
    user = User.find params[:id]
    unless current_user?(user)
      redirect_to root_path
    end
  end

end
