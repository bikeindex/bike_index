class ApplicationController < ActionController::Base
  include AuthenticationHelper
  protect_from_forgery
  helper_method :current_user, :current_organization, :user_root_url,
                :remove_session, :revised_layout_enabled?
  before_filter :enable_rack_profiler

  ensure_security_headers(csp: false,
    hsts: { max_age: 20.years.to_i, include_subdomains: false },
    x_frame_options: 'SAMEORIGIN',
    x_content_type_options: 'nosniff',
    x_xss_protection: false,
    x_download_options: false,
    x_permitted_cross_domain_policies: false)

  def current_organization
    @current_organization ||= Organization.friendly_find(params[:organization_id])
  end

  def enable_rack_profiler
    if current_user && current_user.developer?
      Rack::MiniProfiler.authorize_request unless Rails.env.test?
    end
  end

  def append_info_to_payload(payload)
    super
    payload[:ip] = request.headers['CF-Connecting-IP']
  end

  def handle_unverified_request
    remove_session
    flash[:error] = "CSRF invalid. If you weren't intentionally doing something dumb, please contact us"
    redirect_to goodbye_url
  end

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, PUT, GET, OPTIONS'
    headers['Access-Control-Request-Method'] = '*'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
    headers['Access-Control-Max-Age'] = "1728000"
  end

  def store_return_to
    session[:return_to] = params[:return_to] if params[:return_to].present?
  end

  def set_return_to(return_path)
    session[:return_to] = return_path
  end

  def return_to_if_present
    if session[:return_to].present? || cookies[:return_to].present?
      target = session[:return_to] || cookies[:return_to]
      session[:return_to] = nil
      cookies[:return_to] = nil
      case target.downcase
      when 'password_reset'
        flash[:success] = "You've been logged in. Please reset your password"
        render action: :update_password and return true
      when /\A#{ENV['BASE_URL']}/, /\A\//
        redirect_to(target) and return true
      when 'https://facebook.com/bikeindex'
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
