class ApplicationController < ActionController::Base
  include UrlHelper
  include AuthenticationHelper
  protect_from_forgery
  ensure_security_headers
  helper_method :current_user, :current_organization, :user_root_url, :remove_session
  

  def handle_unverified_request
    remove_session
    flash[:notice] = "CSRF invalid. If you weren't intentionally doing something dumb, please contact us"
    redirect_to goodbye_url
  end

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, PUT, GET, OPTIONS'
    headers['Access-Control-Request-Method'] = '*'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
    headers['Access-Control-Max-Age'] = "1728000"
  end

  def set_return_to
    session[:return_to] = params[:return_to] if params[:return_to].present?
  end

  def return_to_if_present
    if session[:return_to].present? || cookies[:return_to].present?
      target = session[:return_to] || cookies[:return_to]
      session[:return_to] = nil
      cookies[:return_to] = nil
      case target.downcase
      when 'password_reset'
        flash[:notice] = "You've been logged in. Please reset your password"
        render action: :update_password and return true
      when /\A#{ENV['BASE_URL']}/, /\A\//
        redirect_to(target) and return true
      end
    elsif session[:discourse_redirect]
      redirect_to discourse_authentication_url
    end
  end

  # If this is a preflight OPTIONS request, then short-circuit the
  # request, return only the necessary headers and return an empty
  # text/plain.
  def cors_preflight_check
    if request.method == :options
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
      headers['Access-Control-Allow-Headers'] = '*'
      headers['Access-Control-Max-Age'] = '1728000'
      render text: '', content_type: 'text/plain'
    end
  end

end
