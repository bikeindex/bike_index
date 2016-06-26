=begin
*****************************************************************
* File: app/controllers/application_controller.rb 
* Name: Class ApplicationController 
* Some methods to use the entire application
*****************************************************************
=end

class ApplicationController < ActionController::Base
  
  # Must use AuthenticationHelper in this class so included in
  include AuthenticationHelper
  include AssertHelper
  protect_from_forgery
  ensure_security_headers
  before_filter :set_locale
  
=begin
  Need to call some authentication helper, 
  but not all, so declare helper_method with some of then    
=end
  helper_method :current_user, :current_organization, :user_root_url,
                :remove_session, :revised_layout_enabled?
  
  # Condition 
  before_filter :enable_rack_profiler

=begin
  Name: enable_rack_profiler
  Explication: recive current_user and check if his is user developer
  Params: user_parms
  Return: send able the authorize request
=end
  def enable_rack_profiler
    if current_user && current_user.developer?
      Rack::MiniProfiler.authorize_request unless Rails.env.test?
    else
      #nothing to do
    end
  end

=begin
  Name: set_revised_layout
  Explication: just check if layout is already revised
  Params: none
  Return: set a able layout revised
=end 
  def set_revised_layout
    self.class.layout 'application_revised' if revised_layout_enabled?
  end

=begin
  Name: handle_unverified_request
  Explication: Method to validate te request CSRF 
  Params: none
  Return: Warning to user, tell him that he's doing somethig wrong
=end 
  def handle_unverified_request
    remove_session
    flash[:notice] = "CSRF invalid. If you weren't intentionally doing something dumb, please contact us"
    redirect_to goodbye_url
  end

=begin
  Name: cors_set_access_control_headers
  Explication: establish headers to control access
  Params: none
  Return: 1728000
=end
  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, PUT, GET, OPTIONS'
    headers['Access-Control-Request-Method'] = '*'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
    headers['Access-Control-Max-Age'] = "1728000"
  end

=begin
  Name: set_return_to
  Explication: check if session with return_to params are ok (present)
  Params: return_to (see this method params)
  Return: return session, if params are ok (present)
=end
  def set_return_to
    session[:return_to] = params[:return_to] if params[:return_to].present?
  end

=begin
  Name: return_to_if_present
  Explication: check if user is already logged (call method present) 
  in and allow him to change (reset) his password.
  Params: user password
  Return: permission to user change his password
=end
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
    else
      #nothing to do
    end  
    if session[:discourse_redirect]
      redirect_to discourse_authentication_url
    else
      #nothing to do
    end
  end

=begin
  Name: cors_preflight_check
  Explication: verify the options in the request method 
  Params: none
  Return: If this is a preflight OPTIONS request, then short-circuit the
  request, return only the necessary headers and return an empty
  text/plain.
=end  
  def cors_preflight_check
    if request.method == :options
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
      headers['Access-Control-Allow-Headers'] = '*'
      headers['Access-Control-Max-Age'] = '1728000'
      render text: '', content_type: 'text/plain'
    else
      #nothing to do
    end
  end

=begin
  Name: assert_message
  Explication: redirect user to one page with assert message
  Params: condition
=end
  def assert_message(condition)
    if (condition)
      # if condition pass the program keep runnig
    else 
      redirect_to assert_path
      #server_exception = stop the program
    end
  end

  private
    def set_locale
      I18n.locale = params[:locale] if params[:locale].present?
    end

    def default_url_options(options = {})
      {locale: I18n.locale}
    end
  
end

