class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  include SessionsHelper

  before_action :authenticate

  private

  def authenticate
    unless current_user.present?
      redirect_to(root_url, alert: 'You are not authorized. Please log in.') 
    end
  end

  def authenticate_manager
    unless manager_logged_in?
      redirect_to(manager_login_path, alert: 'You are not a manager. Please log in with manager credentials.') 
    end
  end

end
