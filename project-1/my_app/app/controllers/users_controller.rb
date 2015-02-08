class UsersController < ApplicationController

  before_action :set_user, only: [:show, :destroy]
  before_action :correct_user, only: [:show]

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
        format.html { redirect_to @user, notice: 'User was successfully created.' }
        format.json { render :show, status: :created, location: @user }
      else
        format.html { render :new }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
  end
  
  # # DELETE /users/1
  # # DELETE /users/1.json
  # def destroy
  #   user = @user
  #   @user.destroy
  #   respond_to do |format|
  #     format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
  #     format.json { head :no_content }
  #   end
  # end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  def correct_user
    user = User.find(params[:id])
    if !current_user?(user)
      # Redirect to log in with error message
      redirect_to(root_url, alert: 'You are not authorized. Please log in.') 
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_params
    params.require(:user).permit(:login, :password)
  end

end
