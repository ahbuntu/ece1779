module SessionsHelper
  
  # Logs in the given user
  def log_in(user)
    session[:user_id] = user.id
  end

  def current_user
    return unless session[:user_id]
    @current_user ||= User.find_by_id session[:user_id]
  end

  # Returns true if a user is logged in, false otherwise.
  def logged_in?
    !current_user.nil?
  end
  
  # Logs out the current user.
  def log_out
    session.delete(:user_id)
    @current_user = nil
  end

  def current_user?(user)
    user == current_user
  end

##########################################
  
  def managerCreds
    creds = YAML.load(File.read('config/manager.yml'))[Rails.env.to_s]
    {"login" => creds["manager"]["login"], "password" => creds["manager"]["password"]}
  end

  def adminCreds
    creds = YAML.load(File.read('config/manager.yml'))[Rails.env.to_s]
    {"login" => creds["admin"]["login"], "password" => creds["admin"]["password"]}
  end

  # Logs in the given manager
  def log_in_manager
    session[:manager_id] = "manager"
  end

  def is_manager?(login, password)
    managerCreds["login"] == login && managerCreds["password"] == password
  end

  # Returns true if a manager is logged in, false otherwise.
  def manager_logged_in?
    !session[:manager_id].nil?
  end
  
  # Logs out the current user.
  def log_out_manager
    session.delete(:manager_id)
  end

end
