class ApplicationController < ActionController::Base
  include ControllerHelpers
  include Binxtils::SetPeriod
  include Turbo::Redirection
  include Pagy::Method

  self.default_earliest_time = Time.at(1134972000).freeze # Earliest bike created at

  protect_from_forgery

  before_action :normalize_page_param
  before_action :set_paper_trail_whodunnit
  around_action :set_locale
  rescue_from Money::Bank::UnknownRate, with: :localization_failure
  rescue_from Pagy::RangeError, with: :redirect_to_last_page
  # A "null" Origin raises from Rails' origin check rather than calling handle_unverified_request
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_unverified_request

  def allow_x_frame
    SecureHeaders.opt_out_of_header(request, :x_frame_options)
  end

  def handle_unverified_request
    flash[:error] = invalid_authenticity_token_message
    redirect_to user_root_url
  end

  # Shared with the controllers that override handle_unverified_request to re-render
  def invalid_authenticity_token_message
    translation(:invalid_authenticity_token, scope: [:controllers, :application, :handle_unverified_request])
  end

  def cors_set_access_control_headers
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = "POST, PUT, GET, OPTIONS"
    headers["Access-Control-Request-Method"] = "*"
    headers["Access-Control-Allow-Headers"] = "Origin, X-Requested-With, Content-Type, Accept, Authorization"
    headers["Access-Control-Max-Age"] = "1728000"
  end

  # If this is a preflight OPTIONS request, then short-circuit the
  # request, return only the necessary headers and return an empty
  # text/plain.
  def cors_preflight_check
    if request.method == :options
      headers["Access-Control-Allow-Origin"] = "*"
      headers["Access-Control-Allow-Methods"] = "POST, GET, OPTIONS"
      headers["Access-Control-Allow-Headers"] = "*"
      headers["Access-Control-Max-Age"] = "1728000"
      render plain: ""
    end
  end

  def force_html_response
    request.format = "html"
  end

  private

  # Drop a non-scalar `page` (eg the `page[$eq]=2` injection probe) - pagination
  # helpers expect a scalar and otherwise raise on `.to_i`
  def normalize_page_param
    page = params[:page]
    params.delete(:page) if page.present? && !page.is_a?(String) && !page.is_a?(Integer)
  end

  def user_for_paper_trail
    current_user&.id
  end

  def permitted_org_registration_search_params
    @stolenness ||= params["stolenness"].present? ? params["stolenness"] : "all"
    params.permit(*Bike.permitted_search_params).merge(stolenness: @stolenness)
      .to_h # Use to_h here to prevent unpermitted params logs over and over
  end

  def locale_from_request_header
    request.env.fetch("HTTP_ACCEPT_LANGUAGE", "").scan(/^[a-z]{2}/).first
  end

  def locale_from_request_params
    params[:locale].to_s.strip
  end

  def requested_locale
    @requested_locale ||= available_locale(locale_from_request_params.presence || implicit_locale)
  end

  # The locale the request would render in without its locale param, which is what makes the
  # param redundant -- default_url_options drops one rather than trailing it across every link
  def implicit_locale
    @implicit_locale ||= available_locale(current_user&.preferred_language.presence ||
      locale_from_request_header.presence)
  end

  def available_locale(locale)
    I18n.available_locales.include?(locale.to_s.to_sym) ? locale : I18n.default_locale
  end

  def default_url_options(options = {})
    return options if locale_from_request_params.blank? ||
      locale_from_request_params == implicit_locale.to_s

    {locale: locale_from_request_params}.merge(options)
  end

  # Around filter to ensure locale (language and timezone) are set only per request
  def set_locale(&action)
    # Parse the timezone params if they are passed (tested in admin#dashboard#index)
    if params[:timezone].present?
      timezone = Binxtils::TimeZoneParser.parse(params[:timezone])
      # If it's a valid timezone, save to session
      session[:timezone] = timezone&.name
    end
    # Set the timezone on a per request basis if we have a timezone saved
    if session[:timezone].present?
      Time.zone = timezone || Binxtils::TimeZoneParser.parse(session[:timezone])
    end

    # We aren't translating the superadmin section
    if controller_namespace == "admin"
      return I18n.with_locale(I18n.default_locale, &action)
    end

    I18n.with_locale(requested_locale, &action)
  ensure # Make sure we reset default timezone
    Time.zone = Binxtils::TimeParser.default_time_zone
  end

  def earliest_organization_period_date
    return nil if current_organization.blank?

    start_time = current_organization.created_at - 6.months
    start_time = Time.current - 1.year if start_time > (Time.current - 1.year)
    start_time
  end

  def earliest_period_date
    earliest_organization_period_date || default_earliest_time
  end

  # Handle localization / currency conversion exceptions by redirecting to the
  # root url with the default locale and a flash message.
  def localization_failure
    locale = translation(requested_locale, scope: [:locales])
    flash[:error] = "#{locale} localization is unavailable. Please try again later."
    params.delete(:locale)
    redirect_to root_url
  end

  # Redirect to last valid page when page is out of range
  # Replicates the old pagy overflow: :last_page behavior
  def redirect_to_last_page(exception)
    redirect_to url_for(page: exception.pagy.last), allow_other_host: false
  end
end
