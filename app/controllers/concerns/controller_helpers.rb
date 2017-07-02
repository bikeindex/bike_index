# This is a concern so it can be included in controllers that don't inherit
# from ApplicationController - e.g. Doorkeeper controllers
module ControllerHelpers
  extend ActiveSupport::Concern
  include AuthenticationHelper

  included do
    helper_method :current_user, :current_organization, :user_root_url, :controller_namespace,
                  :page_id, :remove_session, :ensure_preview_enabled!, :forwarded_ip_address,
                  :recovered_bike_count
    before_filter :enable_rack_profiler
  end

  def enable_rack_profiler
    if current_user && current_user.developer?
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
    @current_organization ||= Organization.friendly_find(params[:organization_id])
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
