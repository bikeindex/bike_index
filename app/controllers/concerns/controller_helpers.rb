# This is a concern so it can be included in controllers that don't inherit
# from ApplicationController - e.g. Doorkeeper controllers

module ControllerHelpers
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :current_user_or_unconfirmed_user, :sign_in_partner, :user_root_url,
                  :active_organization, :current_organization, :set_current_organization,
                  :controller_namespace, :page_id, :recovered_bike_count
    before_filter :enable_rack_profiler
  end

  def enable_rack_profiler
    return false unless current_user&.developer?
    Rack::MiniProfiler.authorize_request unless Rails.env.test?
  end

  def authenticate_user(msg = "Sorry, you have to log in", flash_type: :error)
    # Make absolutely sure the current user is confirmed - mainly for testing
    if current_user&.confirmed?
      return true if current_user.terms_of_service
      redirect_to accept_terms_url(subdomain: false) and return
    elsif current_user&.unconfirmed? || unconfirmed_current_user.present?
      redirect_to please_confirm_email_users_path and return
    else
      flash[flash_type] = msg
      if msg.match(/create an account/i).present?
        redirect_to new_user_url(subdomain: false, partner: sign_in_partner) and return
      else
        redirect_to new_session_url(subdomain: false, partner: sign_in_partner) and return
      end
    end
  end

  def render_partner_or_default_signin_layout(render_action: nil, redirect_path: nil)
    layout = sign_in_partner == "bikehub" ? "application_revised_bikehub" : "application_revised"
    if redirect_path
      redirect_to redirect_path, layout: layout
    elsif render_action
      render action: render_action, layout: layout
    else
      render layout: layout
    end
  end

  def user_root_url
    return root_url unless current_user.present?
    return admin_root_url if current_user.superuser
    return user_home_url(subdomain: false) unless current_user.default_organization.present?
    organization_bikes_path(organization_id: current_user.default_organization.to_param)
  end

  # Generally this is implicitly set, via the passed parameters - however! it can also be explicitly set
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

  def controller_namespace
    @controller_namespace ||= self.class.parent.name != "Object" ? self.class.parent.name.downcase : nil
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

  def ensure_preview_enabled!
    return true if preview_enabled?
    flash[:notice] = "Sorry, you don't have permission to view that page"
    redirect_to user_root_url and return
  end

  def set_current_organization(organization)
    session[:current_organization_id] = organization&.id || "0"
    @current_organization = organization
  end

  protected

  # current_organization is the organization set for the user - which is persisted in session
  # The user may or may not be interacting with the active_organization in any given request
  def current_organization
    return @current_organization if defined?(@current_organization)
    if session[:current_organization_id].present?
      return @current_organization = nil if session[:current_organization_id].to_i == 0
      @current_organization = Organization.friendly_find(session[:current_organization_id])
    end
    @current_organization ||= set_current_organization(current_user&.default_organization)
  end

  # active_organization is the organization currently being used.
  # If set, the user *is* interacting with the organization in said request 
  def active_organization
    # We call this multiple times - make sure nil stays nil
    return @active_organization if defined?(@active_organization)
    @active_organization = Organization.friendly_find(params[:organization_id])
    set_current_organization(@active_organization)
  end

  def current_user
    # always reassign if nil - this value changes during sign in and removing ivars is scary
    @current_user ||= User.confirmed.from_auth(cookies.signed[:auth])
  end

  def unconfirmed_current_user
    @unconfirmed_current_user ||= User.unconfirmed.from_auth(cookies.signed[:auth])
  end

  # Because we need to show unconfirmed users logout - and we should show them what they're missing in general
  # Generally, this shouldn't be accessed. Almost always should be accessing current_user
  def current_user_or_unconfirmed_user
    current_user_or_unconfirmed_user = current_user || unconfirmed_current_user
  end

  def sign_in_partner
    return @sign_in_partner if defined?(@sign_in_partner)
    # We set partner in session because of AuthorizationsController - but we don't want the session to stick around
    # so people can navigate around the site and return to the sign in without unexpected results
    # we ALWAYS want to remove the session partner
    partner = session.delete(:partner)
    partner ||= params[:partner]
    # fallback to assigning via session, but if partner was set via param, still remove the session partner.
    @sign_in_partner = partner&.downcase == "bikehub" ? "bikehub" : nil # For now, only permit bikehub partner
  end

  def remove_session
    session.keys.each { |k| session.delete(k) } # Get rid of everything we've been storing
    cookies.delete(:auth)
  end

  def preview_enabled?
    (current_user && $rollout.active?(:preview, current_user)) || (params && params[:preview])
  end

  def require_member!
    return true if current_user.member_of?(active_organization)
    flash[:error] = "You're not a member of that organization!"
    redirect_to user_home_url(subdomain: false) and return
  end

  def require_admin!
    return true if current_user.admin_of?(active_organization)
    flash[:error] = "You have to be an organization administrator to do that!"
    redirect_to user_home_url and return
  end

  def require_index_admin!
    type = "full"
    content_accessible = ["news"]
    type = "content" if content_accessible.include?(controller_name)
    return true if current_user.present? && current_user.superuser?
    flash[:error] = "You don't have permission to do that!"
    redirect_to user_root_url and return
  end
end
