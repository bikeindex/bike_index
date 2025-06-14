# This is a concern so it can be included in controllers that don't inherit
# from ApplicationController - e.g. Doorkeeper controllers

module ControllerHelpers
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :current_user_or_unconfirmed_user, :sign_in_partner, :user_root_url,
      :user_root_bike_search?, :current_organization, :passive_organization, :current_location,
      :controller_namespace, :page_id, :default_bike_search_path, :bikehub_url, :show_general_alert,
      :display_dev_info?, :current_country_id, :current_currency
    before_action :enable_rack_profiler

    before_action do
      if Rails.env.production?
        unless request.host == base_url_host
          redirect_to("https://#{base_url_host}#{request.fullpath}", status: :moved_permanently, allow_other_host: true)
        end
        if current_user.present?
          Honeybadger.context(user_id: current_user.id, user_email: current_user.email)
        end
      end
    end
  end

  def base_url_host
    ENV.fetch("BASE_URL", "bikeindex.org").delete_prefix("https://").freeze
  end

  def append_info_to_payload(payload)
    super
    payload[:ip] = forwarded_ip_address
    payload[:u_id] = current_user&.id
  end

  def forwarded_ip_address
    @forwarded_ip_address ||= IpAddressParser.forwarded_address(request)
  end

  def request_location_hash
    @request_location_hash ||= IpAddressParser.location_hash(request)
  end

  # TODO: make this actually use the request location
  def current_currency
    Currency.default
  end

  def current_country_id
    request_location_hash[:country_id]
  end

  def enable_rack_profiler
    return false unless current_user&.developer? && !Rails.env.test?
    Rack::MiniProfiler.authorize_request
  end

  def display_dev_info?
    return @display_dev_info if defined?(@display_dev_info)
    # Tie display_dev_info to the rack mini profiler display
    # add ?pp=disable to the URL to disable miniprofiler temporarily
    @display_dev_info = !Rails.env.test? && current_user&.developer? &&
      Rack::MiniProfiler.current.present?
  end

  def set_reading_role
    ActiveRecord::Base.connected_to(role: :reading) do
      yield
    end
  end

  def store_return_and_authenticate_user(translation_key: nil, flash_type: :error)
    return if current_user&.confirmed? && current_user.terms_of_service

    store_return_to
    authenticate_user(flash_type:) && return
  end

  def authenticate_user(translation_key: nil, translation_args: {}, flash_type: :error)
    translation_key ||= :you_have_to_log_in

    # Make absolutely sure the current user is confirmed - mainly for testing
    if current_user&.confirmed?
      return true if current_user.terms_of_service
      redirect_to(accept_terms_url) && return
    elsif current_user&.unconfirmed? || unconfirmed_current_user.present?
      redirect_to(please_confirm_email_users_path) && return
    else
      force_sign_up = params[:unauthenticated_redirect] == "sign_up" # other option is sign_in
      unless force_sign_up # Force signup doesn't show a flash message
        flash[flash_type] = translation(
          translation_key,
          **translation_args,
          scope: [:controllers, :concerns, :controller_helpers, __method__]
        )
      end

      if force_sign_up || translation_key.to_s.match?(/create.+account/)
        redirect_to(new_user_url(partner: sign_in_partner)) && return
      else
        redirect_to(new_session_url(partner: sign_in_partner)) && return
      end
    end
  end

  def render_partner_or_default_signin_layout(render_action: nil, redirect_path: nil)
    layout = (sign_in_partner == "bikehub") ? "application_bikehub" : "application"
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
    return admin_root_url if current_user.superuser?
    return my_account_url unless current_user.default_organization.present?
    if user_root_bike_search?
      default_bike_search_path
    else
      organization_root_url(organization_id: current_user.default_organization.to_param)
    end
  end

  def show_general_alert
    return @show_general_alert = false if @skip_general_alert || current_user.blank?
    ignored_alerts = Flipper.enabled?(:phone_verification) ? [] : %w[phone_waiting_confirmation]
    return @show_general_alert = false unless (current_user.alert_slugs - ignored_alerts).any?

    no_alerts = %w[payments theft_alerts].include?(controller_name) || %w[support_bike_index].include?(action_name)
    @show_general_alert = !no_alerts
  end

  def default_bike_search_path
    search_registrations_path(stolenness: "all")
  end

  def ensure_current_organization!
    return true if current_organization.present?
    fail ActiveRecord::RecordNotFound
  end

  # Generally this is implicitly set - however! it can also be explicitly set
  def store_return_to(target = nil)
    # fallback to the return to parameters, or the current path
    target ||= params[:return_to] ||
      [request.env["PATH_INFO"], request.env["QUERY_STRING"]].reject(&:blank?).join("?")

    session[:return_to] = target unless invalid_return_to?(target)
  end

  def return_to_if_present
    if session[:return_to].present? || cookies[:return_to].present? || params[:return_to]
      # NOTE: This is duplicated in permitted_return_to
      target = session[:return_to] || cookies[:return_to] || params[:return_to]
      session[:return_to] = nil
      cookies[:return_to] = nil

      return false if invalid_return_to?(target)
      handle_target(target)
    elsif session[:discourse_redirect]
      redirect_to(discourse_authentication_url, allow_other_host: true) && (return true)
    end
  end

  def handle_target(target)
    case target.downcase
    when "password_reset"
      flash[:success] =
        translation(:reset_your_password,
          scope: [:controllers, :concerns, :controller_helpers, __method__])
      render(action: :update_password) && (return true)
    when /\A#{ENV["BASE_URL"]}/, %r{\A/} # Either starting with our URL or /
      redirect_to(target) && (return true) if URI.parse(target).relative? || target.include?("/oauth/")
    when "https://facebook.com/bikeindex"
      redirect_to(target, allow_other_host: true) && (return true)
    end
  end

  def permitted_return_to
    target = (session[:return_to] || cookies[:return_to] || params[:return_to])&.downcase
    return nil if invalid_return_to?(target)
    # Either starting with our URL or /
    target if target.start_with?(/#{ENV["BASE_URL"]}/, "/")
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
          .reject { |label| label.include?("rescue in") }
          .first
    end

    scope ||= [:controllers, controller_namespace, controller_name, controller_method.to_sym]
    I18n.t(key, **kwargs, scope: scope.compact)
  end

  def controller_namespace
    return @controller_namespace if defined?(@controller_namespace)
    @controller_namespace = if self.class.module_parent.name != "Object"
      self.class.module_parent.name.underscore.downcase
    end
  end

  # This is overridden in FeedbacksController and InfoController
  def page_id
    @page_id ||= [
      controller_namespace,
      (controller_name == "manages") ? "manage" : controller_name, # HACK: remove pluralization
      action_name
    ].compact.join("_")
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
    if @period == "custom"
      if params[:start_time].present?
        @start_time = TimeParser.parse(params[:start_time], @timezone)
        @end_time = TimeParser.parse(params[:end_time], @timezone) || latest_period_date
        if @start_time > @end_time
          new_end_time = @start_time
          @start_time = @end_time
          @end_time = new_end_time
        end
      else
        set_time_range_from_period
      end
    elsif params[:search_at].present?
      @period = "custom"
      @search_at = TimeParser.parse(params[:search_at], @timezone)
      offset = params[:period].present? ? params[:period].to_i : 10.minutes.to_i
      @start_time = @search_at - offset
      @end_time = @search_at + offset
    else
      set_time_range_from_period
    end
    # Add this render_chart in here so we don't have to define it in all the controllers
    @render_chart = InputNormalizer.boolean(params[:render_chart])
    @time_range = @start_time..@end_time
  end

  def sign_in_if_not!
    return true unless params[:sign_in_if_not].present? && current_user.blank?
    return ensure_member_of!(current_organization) if params[:organization_id].present?
    store_return_to
    flash[:notice] = translation(:please_sign_in,
      scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to(new_session_path) && return
  end

  def turbo_request?
    request.format.turbo_stream? || turbo_frame_request?
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
    if params[:organization_id] == "false" # Enable removing current organization
      @current_organization = nil
      @current_organization_force_blank = true
    else
      @current_organization = Organization.friendly_find(params[:organization_id])
      # Sometimes (e.g. embed registration), it's ok if current_user isn't authorized - but only set passive_organization if authorized
      return @current_organization unless @current_organization.present? && current_user&.authorized?(@current_organization)
    end
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
    @sign_in_partner = (partner&.downcase == "bikehub") ? "bikehub" : nil # For now, only permit bikehub partner
  end

  def remove_session
    session.keys.each { |k| session.delete(k) } # Get rid of everything we've been storing
    cookies.delete(:auth)
  end

  def require_member!
    return true if current_user.member_of?(current_organization)
    flash[:error] = translation(:not_an_org_member, scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to(my_account_url) && return
  end

  def require_admin!
    return true if current_user.admin_of?(current_organization)
    flash[:error] = translation(:not_an_org_admin, scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to(my_account_url) && return
  end

  def require_index_admin!
    if current_user.present?
      return true if current_user.superuser?
      return true if current_user.superuser_abilities.can_access?(controller_name: controller_name, action_name: action_name)
    end
    flash[:error] = translation(:not_permitted_to_do_that, scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to(user_root_url) && return
  end

  def ensure_member_of!(passed_organization)
    if current_user&.member_of?(passed_organization)
      return true if current_user.accepted_vendor_terms_of_service?
      flash[:success] = translation(:accept_tos_for_orgs,
        scope: [:controllers, :concerns, :controller_helpers, __method__])
      redirect_to(accept_vendor_terms_path) && return
    elsif current_user.blank?
      flash[:notice] = translation(:please_sign_in,
        scope: [:controllers, :concerns, :controller_helpers, __method__])
      store_return_to
      sign_in_path = set_passive_organization(passed_organization)&.enabled?("passwordless_users") ? magic_link_session_path : new_session_path
      redirect_to(sign_in_path) && return
    end
    set_passive_organization(nil) # remove the active organization, because it failed so don't show it anymore
    flash[:error] = translation(:not_a_member_of_that_org,
      scope: [:controllers, :concerns, :controller_helpers, __method__])
    redirect_to(user_root_url) && return
  end

  def invalid_return_to?(target)
    return true if target.blank?
    # return_to can't be a sign in/up page, or we'll loop
    ["/users/new", "/session/new", "/session/magic_link", "/integrations", "/users/please_confirm_email"].any? { |r| target.match?(r) }
  end

  def bikehub_url(path = nil)
    "#{valid_partner_domain || "https://parkit.bikehub.com"}/#{path}"
  end

  def bikehub_website_url(path = nil)
    "#{valid_partner_domain || "https://bikehub.com"}/#{path}"
  end

  def valid_partner_domain
    # Sometimes might just be return_to, but if there is a redirect_uri query param, use that
    redirect_redirect_uri = Addressable::URI.parse(session[:return_to])&.query_values&.dig("redirect_uri")
    redirect_redirect_uri ||= session[:return_to] || params[:return_to]
    redirect_site = Addressable::URI.parse(redirect_redirect_uri)&.site&.downcase
    return nil if redirect_site.blank?
    # redirect_site = Addressable::URI.parse(redirect_redirect_uri)&
    # Get redirect uris from BikeHub app and BikeHub dev app (by their ids)
    valid_redirect_urls = Doorkeeper::Application.where(id: [264, 356]).pluck(:redirect_uri)
      .map { |u| u.downcase.split("\s") }.flatten.map(&:strip)
    (valid_redirect_urls.any? { |u| u.start_with?(redirect_site) }) ? redirect_site : nil
  end

  def set_time_range_from_period
    @period = default_period unless %w[hour day month year week all next_week next_month].include?(@period)
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
    when "next_month"
      @start_time ||= Time.current
      @end_time = Time.current.beginning_of_day + 30.days
    when "next_week"
      @start_time = Time.current
      @end_time = Time.current.beginning_of_day + 1.week
    when "all"
      @start_time = earliest_period_date
      @end_time = latest_period_date
    end
    @end_time ||= Time.current
  end

  # Separate method so it can be overridden on per controller basis
  def default_period
    "all"
  end

  # Separate method so it can be overriden, specifically in invoices
  def latest_period_date
    Time.current
  end

  def earliest_organization_period_date
    return nil if current_organization.blank?
    start_time = current_organization.created_at - 6.months
    start_time = Time.current - 1.year if start_time > (Time.current - 1.year)
    start_time
  end

  # Separate method so it can be overridden on per controller basis
  # Copied
  def earliest_period_date
    earliest_organization_period_date || Time.at(1134972000) # Earliest bike created at
  end
end
