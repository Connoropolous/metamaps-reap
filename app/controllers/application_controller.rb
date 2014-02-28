class ApplicationController < ActionController::Base
  protect_from_forgery
  
  # If you do not want to set the format to :mobile or :tablet and only use the helper functions, pass false as an argument.
  has_mobile_fu
  
  # this is for global login
  include ContentHelper
  
  helper_method :user
  helper_method :authenticated?
  
  after_filter :store_location

  def store_location
    # store last url - this is needed for post-login redirect to whatever the user last visited.
    if (!request.fullpath.match("/users/") && !request.xhr?) # don't store ajax calls
      session[:previous_url] = request.fullpath
    end
  end

  def after_sign_in_path_for(resource)
    session[:previous_url] || root_path
  end
  
  def after_sign_up_path_for(resource)
    root_path
  end
  
private

  def require_no_user
    if authenticated?
      flash[:warning] = "You must be logged out."
      store and redirect_to edit_user_path(user)
      return false
    end
  end
  
  def require_user
    unless authenticated?
      flash[:warning] = "You must be logged in."
      store_location and redirect_to new_user_session_path
      return false
    end
  end
  
  def user
    current_user
  end
  
    
  def authenticated?
    current_user
  end
  
end
