class ApplicationController < ActionController::Base
  include ControllerHelpers
  protect_from_forgery

  around_action :set_locale
  rescue_from Money::Bank::UnknownRate, with: :localization_failure

  ensure_security_headers(csp: false,
                          hsts: "max-age=#{20.years.to_i}",
                          x_frame_options: "SAMEORIGIN",
                          x_content_type_options: "nosniff",
                          x_xss_protection: false,
                          x_download_options: false,
                          x_permitted_cross_domain_policies: false)

  def handle_unverified_request
    flash[:error] = translation(:csrf_invalid, scope: [:controllers, :application, __method__])
    redirect_to user_root_url
  end

  def cors_set_access_control_headers
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = "POST, PUT, GET, OPTIONS"
    headers["Access-Control-Request-Method"] = "*"
    headers["Access-Control-Allow-Headers"] = "Origin, X-Requested-With, Content-Type, Accept, Authorization"
    headers["Access-Control-Max-Age"] = "1728000"
  end

  def permit_cross_site_iframe!
    headers["X-Frame-Options"] = nil
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

  def permitted_org_bike_search_params
    @stolenness ||= params["stolenness"].present? ? params["stolenness"] : "all"
    params.permit(*Bike.permitted_search_params).merge(stolenness: @stolenness)
  end

  def default_url_options(options = {})
    # forward locale param when provided
    params.permit(:locale).merge(options)
  end

  def locale_from_request_header
    request.env.fetch("HTTP_ACCEPT_LANGUAGE", "").scan(/^[a-z]{2}/).first
  end

  def locale_from_request_params
    params[:locale].to_s.strip
  end

  def requested_locale
    return @requested_locale if defined?(@requested_locale)

    requested_locale =
      locale_from_request_params.presence ||
      current_user&.preferred_language.presence ||
      locale_from_request_header.presence

    @requested_locale =
      if I18n.available_locales.include?(requested_locale.to_s.to_sym)
        requested_locale
      else
        I18n.default_locale
      end
  end

  # Around filter to ensure locale (language and timezone) are set only per request
  def set_locale(&action)
    # Parse the timezone params if they are passed (tested in admin#dashboard#index)
    if params[:timezone].present?
      timezone = TimeParser.parse_timezone(params[:timezone])
      # If it's a valid timezone, save to session
      session[:timezone] = timezone&.name
    end
    # Set the timezone on a per request basis if we have a timezone saved
    if session[:timezone].present?
      Time.zone = timezone || TimeParser.parse_timezone(session[:timezone])
    end

    # We aren't translating the superadmin section
    if controller_namespace == "admin"
      return I18n.with_locale(I18n.default_locale, &action)
    end
    I18n.with_locale(requested_locale, &action)
  ensure # Make sure we reset default timezone
    Time.zone = TimeParser::DEFAULT_TIMEZONE
  end

  # Handle localization / currency conversion exceptions by redirecting to the
  # root url with the default locale and a flash message.
  def localization_failure
    locale = t(requested_locale, scope: [:locales])
    flash[:error] = "#{locale} localization is unavailable. Please try again later."
    params.delete(:locale)
    redirect_to root_url
  end
end
