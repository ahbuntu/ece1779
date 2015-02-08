class SessionsController < ApplicationController

  def new
  end

  def create 
    user = User.find_by(login: params[:session][:login], password: params[:session][:password])
    if user.present?
      # Log the user in and redirect to the user's show page.
      log_in(user)
      redirect_to user
    else 
      # Create an error message.
      flash.now[:danger] = 'Incorrect login/password combination'
      render 'new'
    end
  end

  def destroy
    log_out if logged_in?        
    redirect_to root_url
  end
  
end
