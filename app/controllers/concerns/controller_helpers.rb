# This is a concern so it can be included in controllers that don't inherit
# from ApplicationController - e.g. Doorkeeper controllers
module ControllerHelpers
  extend ActiveSupport::Concern
  include AuthenticationHelper

  included do
    helper_method :current_user, :unconfirmed_current_user, :current_organization, :user_root_url,
                  :page_id, :remove_session, :ensure_preview_enabled!, :forwarded_ip_address,
                  :recovered_bike_count, :controller_namespace
    before_filter :enable_rack_profiler
  end

  def enable_rack_profiler
    if current_user&.developer?
      Rack::MiniProfiler.authorize_request unless Rails.env.test?
    end
  end

  def page_id
    @page_id ||= [controller_namespace, controller_name, action_name].compact.join('_')
  end

  def recovered_bike_count
    if Rails.env.production?
      Rails.cache.fetch "recovered_bike_count_#{Date.today.to_formatted_s(:number)}" do
        StolenRecord.recovered.where("date_recovered < ?", Time.zone.now.beginning_of_day).count
      end
    else
      3_021
    end
  end

  def controller_namespace
    @controller_namespace ||= (self.class.parent.name != 'Object') ? self.class.parent.name.downcase : nil
  end

  def current_organization
    # We call this multiple times - make sure nil stays nil
    return @current_organization if defined?(@current_organization)
    @current_organization = Organization.friendly_find(params[:organization_id])
  end

  def current_user
    # always reassign if nil - this value changes during sign in and removing ivars is scary
    @current_user ||= User.confirmed.from_auth(cookies.signed[:auth])
    @current_user&.confirmed? ? @current_user : nil # just make extra sure, critical we don't include unconfirmed
  end

  def unconfirmed_current_user
    @unconfirmed_current_user ||= User.unconfirmed.from_auth(cookies.signed[:auth])
  end

  # Generally this is implicitly set, via the passed parameters. However! it can also be explicitly set
  def store_return_to(return_to = nil)
    return_to ||= params[:return_to]
    session[:return_to] = return_to if return_to.present?
  end

  def return_to_if_present
    if session[:return_to].present? || cookies[:return_to].present? || params[:return_to]
      target = session[:return_to] || cookies[:return_to] || params[:return_to]
      session[:return_to] = nil
      cookies[:return_to] = nil
      case target.downcase
      when 'password_reset'
        flash[:success] = "You've been logged in. Please reset your password"
        render action: :update_password and return true
      when /\A#{ENV['BASE_URL']}/, %r{\A/} # Either starting with our URL or /
        redirect_to(target) and return true
      when 'https://facebook.com/bikeindex'
        redirect_to(target) and return true
      end
    elsif session[:discourse_redirect]
      redirect_to discourse_authentication_url and return true
    end
  end
end
