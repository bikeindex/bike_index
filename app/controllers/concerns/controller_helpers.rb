# This is a concern so it can be included in controllers that don't inherit
# from ApplicationController - e.g. Doorkeeper controllers

module ControllerHelpers
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :current_user_or_unconfirmed_user, :sign_in_partner, :user_root_url,
                  :user_root_bike_search?, :current_organization, :passive_organization, :current_location,
                  :controller_namespace, :page_id, :default_bike_search_path, :bikehub_url, :show_general_alert
    before_action :enable_rack_profiler

    before_action do
      if current_user.present?
        Honeybadger.context(user_id: current_user.id, user_email: current_user.email)
      end
    end
  end

  def append_info_to_payload(payload)
    super
    payload[:ip] = forwarded_ip_address
  end

  def forwarded_ip_address
    @forwarded_ip_address ||= ForwardedIpAddress.parse(request)
  end

  def enable_rack_profiler
    return false unless current_user&.developer?
    Rack::MiniProfiler.authorize_request unless Rails.env.test?
  end

  def authenticate_user(translation_key: nil, translation_args: {}, flash_type: :error)
    translation_key ||= :you_have_to_log_in

    # Make absolutely sure the current user is confirmed - mainly for testing
    if current_user&.confirmed?
      return true if current_user.terms_of_service
      redirect_to accept_terms_url(subdomain: false) and return
    elsif current_user&.unconfirmed? || unconfirmed_current_user.present?
      redirect_to please_confirm_email_users_path and return
    else
      flash[flash_type] = translation(
        translation_key,
        **translation_args,
        scope: [:controllers, :concerns, :controller_helpers, __method__],
      )

      if translation_key.to_s.match?(/create.+account/)
        redirect_to new_user_url(subdomain: false, partner: sign_in_partner) and return
      else
        redirect_to new_session_url(subdomain: false, partner: sign_in_partner) and return
      end
    end
  end

  def render_partner_or_default_signin_layout(render_action: nil, redirect_path: nil)
    layout = sign_in_partner == "bikehub" ? "application_bikehub" : "application"
    if redirect_path
      redirect_to redirect_path, layout: layout
    elsif render_action
      render action: render_action, layout: layout
    else
      render layout: layout
    end
  end

  def user_root_bike_search?
    current_user.present? && current_user.default_organization.present? &&
      current_user.default_organization.law_enforcement?
  end

  def user_root_url
    return root_url unless current_user.present? && current_user.confirmed?
    return admin_root_url if current_user.superuser
    return my_account_url(subdomain: false) unless current_user.default_organization.present?
    if user_root_bike_search?
      default_bike_search_path
    else
      organization_root_url(organization_id: current_user.default_organization.to_param)
    end
  end

  def show_general_alert
    return @show_general_alert = false if @skip_general_alert
    return @show_general_alert = false unless current_user.present? && current_user.general_alerts.any?

    if %w[payments theft_alerts].include?(controller_name) || %w[support_bike_index].include?(action_name)
      @show_general_alert = false
    else
      @show_general_alert = true
    end
  end

  def default_bike_search_path
    bikes_path(stolenness: "all")
  end

  def ensure_current_organization!
    return true if current_organization.present?
    fail ActiveRecord::RecordNotFound
  end

  # Generally this is implicitly set - however! it can also be explicitly set
  def store_return_to(target = nil)
    # fallback to the return to parameters, or the current path
    target ||= params[:return_to] || request.env["PATH_INFO"]
    session[:return_to] = target unless invalid_return_to?(target)
  end

  def return_to_if_present
    if session[:return_to].present? || cookies[:return_to].present? || params[:return_to]
      target = session[:return_to] || cookies[:return_to] || params[:return_to]
      session[:return_to] = nil
      cookies[:return_to] = nil
      return false if invalid_return_to?(target)
      case target.downcase
      when "password_reset"
        flash[:success] =
          translation(:reset_your_password,
                      scope: [:controllers, :concerns, :controller_helpers, __method__])
        render action: :update_password and return true
      when /\A#{ENV["BASE_URL"]}/, %r{\A/} # Either starting with our URL or /
        redirect_to(target) and return true
      when "https://facebook.com/bikeindex"
        redirect_to(target) and return true
      end
    elsif session[:discourse_redirect]
      redirect_to discourse_authentication_url and return true
    end
  end

  # Wrap `I18n.translate` for use in controllers, abstracting away
  # scope-setting. By default, translations are scoped as follows:
  #
  # :controllers
  # > [controller_namespace] (possibly none)
  # > [controller_name]
  # > [controller_method where `translate` is invoked (inferred dynamically not lexically -- see note below)]
  #
  # Either the controller method or the entire scope can be overridden via the
  # corresponding keyword args, the latter taking precedence if both are
  # provided.
  #
  # Note that when `translation` is invoked in an ancestor controller or mixin,
  # `scope` should be provided explicitly, as the calling method will vary
  # dynamically but for the sake of mapping to an entry in the translation file,
  # a one-to-one, lexically-scoped mapping is desirable.
  #
  # For example, in `ApplicationController#handle_unverified_request` we have
  #
  #   flash[:error] = translation(:csrf_invalid, scope: [:controllers, :application, __method__])
  #
  # which maps to controllers.application.handle_unverified_request.csrf_invalid.
  #
  # In `LocksController#find_lock`, by contrast, the full scope can be inferred
  # from the method invocation:
  #
  #   flash[:error] = translation(:not_your_lock)
  #
  # maps to controllers.locks.find_lock.not_your_lock.
  def translation(key, scope: nil, controller_method: nil, **kwargs)
    if scope.blank? && controller_method.blank?
      controller_method =
        caller_locations
          .slice(0, 2)
          .map(&:label)
          .reject { |label| label =~ /rescue in/ }
          .first
    end

    scope ||= [:controllers, controller_namespace, controller_name, controller_method.to_sym]
    I18n.t(key, **kwargs, scope: scope.compact)
  end

  def controller_namespace
    @controller_namespace ||= self.class.parent.name != "Object" ? self.class.parent.name.downcase : nil
  end

  # This is overridden in FeedbacksController
  def page_id
    @page_id ||= [controller_namespace, controller_name, action_name].compact.join("_")
  end

  def set_passive_organization(organization)
    session[:passive_organization_id] = organization&.id || "0"
    @current_organization = organization
    @passive_organization = organization
  end

  # For setting periods, particularly for graphing
  def set_period
    @timezone ||= Time.zone
    # Set time period
    @period ||= params[:period]
    if @period == "custom" && params[:start_time].present?
      @start_time = TimeParser.parse(params[:start_time], @timezone)
      @end_time = TimeParser.parse(params[:end_time], @timezone) || Time.current
      if @start_time > @end_time
        new_end_time = @start_time
        @start_time = @end_time
        @end_time = new_end_time
      end
    else
      set_time_range_from_period
    end
    # Add this render_chart in here so we don't have to define it in all the controllers
    @render_chart = ParamsNormalizer.boolean(params[:render_chart])
    @time_range = @start_time..@end_time
  end

  def sign_in_if_not!
    return true unless params[:sign_in_if_not].present? && current_user.blank?
    return ensure_member_of!(current_organization) if params[:organization_id].present?
    store_return_to
    flash[:notice] = translation(:please_sign_in,
                                 scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to new_session_path and return
  end

  protected

  # passive_organization is the organization set for the user - which is persisted in session
  # The user may or may not be interacting with the current_organization in any given request
  def passive_organization
    return @passive_organization if defined?(@passive_organization)
    if session[:passive_organization_id].present?
      return @passive_organization = nil if session[:passive_organization_id].to_i == 0
      @passive_organization = Organization.friendly_find(session[:passive_organization_id])
    end
    @passive_organization ||= set_passive_organization(current_user&.default_organization)
  end

  # current_organization is the organization currently being used.
  # If set, the user *is* interacting with the organization in said request
  def current_organization
    # We call this multiple times - make sure nil stays nil
    return @current_organization if defined?(@current_organization)
    @current_organization = Organization.friendly_find(params[:organization_id])
    # Sometimes (e.g. embed registration), it's ok if current_user isn't authorized - but only set passive_organization if authorized
    return @current_organization unless @current_organization.present? && current_user&.authorized?(@current_organization)
    set_passive_organization(@current_organization)
  end

  def current_location
    # We call this multiple times - make sure nil stays nil
    return @current_location if defined?(@current_location)
    return @current_location = nil unless current_organization.present?
    if params[:location_id].present?
      @current_location = current_organization.locations.friendly_find(params[:location_id])
    elsif current_organization.locations.count == 1 # If there is only one location, just use that one
      @current_location = current_organization.locations.first if current_organization
    end
    @current_location ||= nil
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
    current_user || unconfirmed_current_user
  end

  def sign_in_partner
    return @sign_in_partner if defined?(@sign_in_partner)
    # We set partner in session because of AuthorizationsController - but we don't want the session to stick around
    # so people can navigate around the site and return to the sign in without unexpected results
    # we ALWAYS want to remove the session partner
    partner = session[:partner]
    partner ||= params[:partner]
    # fallback to assigning via session, but if partner was set via param, still remove the session partner.
    @sign_in_partner = partner&.downcase == "bikehub" ? "bikehub" : nil # For now, only permit bikehub partner
  end

  def remove_session
    session.keys.each { |k| session.delete(k) } # Get rid of everything we've been storing
    cookies.delete(:auth)
  end

  def require_member!
    return true if current_user.member_of?(current_organization)
    flash[:error] = translation(:not_an_org_member, scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to my_account_url(subdomain: false) and return
  end

  def require_admin!
    return true if current_user.admin_of?(current_organization)
    flash[:error] = translation(:not_an_org_admin, scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to my_account_url and return
  end

  def require_index_admin!
    type = "full"
    content_accessible = ["news"]
    type = "content" if content_accessible.include?(controller_name)
    return true if current_user.present? && current_user.superuser?
    flash[:error] = translation(:not_permitted_to_do_that, scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to user_root_url and return
  end

  def ensure_member_of!(passed_organization)
    if current_user && current_user.member_of?(passed_organization)
      return true if current_user.accepted_vendor_terms_of_service?
      flash[:success] = translation(:accept_tos_for_orgs,
                                    scope: [:controllers, :concerns, :controller_helpers, __method__])
      redirect_to accept_vendor_terms_path and return
    elsif current_user.blank?
      flash[:notice] = translation(:please_sign_in,
                                   scope: [:controllers, :concerns, :controller_helpers, __method__])
      store_return_to
      set_passive_organization(passed_organization)
      sign_in_path = passed_organization.enabled?("passwordless_users") ? magic_link_session_path : new_session_path
      redirect_to sign_in_path and return
    end
    set_passive_organization(nil) # remove the active organization, because it failed so don't show it anymore
    flash[:error] = translation(:not_a_member_of_that_org,
                                scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to user_root_url and return
  end

  def invalid_return_to?(target)
    return true if target.blank?
    # return_to can't be a sign in/up page, or we'll loop
    ["/users/new", "/session/new", "/session/magic_link", "/integrations", "/users/please_confirm_email"].any? { |r| target.match?(r) }
  end

  def bikehub_url(path)
    [
      ENV["BIKEHUB_URL"].presence || "https://parkit.bikehub.com",
      path,
    ].join("/")
  end

  def set_time_range_from_period
    @period = default_period unless %w[hour day month year week all].include?(@period)
    case @period
    when "hour"
      @start_time = Time.current - 1.hour
    when "day"
      @start_time = Time.current.beginning_of_day - 1.day
    when "month"
      @start_time = Time.current.beginning_of_day - 30.days
    when "year"
      @start_time = Time.current.beginning_of_day - 1.year
    when "week"
      @start_time = Time.current.beginning_of_day - 1.week
    when "all"
      @start_time = earliest_period_date
    end
    @end_time ||= Time.current
  end

  def default_period # Separate method so it can be overridden on per controller basis
    "all"
  end

  def earliest_period_date # Separate method so it can be overridden on per controller basis
    if current_organization.present?
      @start_time = current_organization.created_at
      @start_time = Time.current - 1.year if @start_time > (Time.current - 1.year)
      @start_time
    else
      @start_time = Time.at(1134972000) # Earliest bike created at
    end
  end
end
