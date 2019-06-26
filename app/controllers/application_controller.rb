class ApplicationController < ActionController::Base
  include ControllerHelpers
  protect_from_forgery
  before_action :set_locale

  ensure_security_headers(csp: false,
                          hsts: "max-age=#{20.years.to_i}",
                          x_frame_options: "SAMEORIGIN",
                          x_content_type_options: "nosniff",
                          x_xss_protection: false,
                          x_download_options: false,
                          x_permitted_cross_domain_policies: false)

  def forwarded_ip_address
    @forwarded_ip_address ||= request.env["HTTP_X_FORWARDED_FOR"].split(",")[0] if request.env["HTTP_X_FORWARDED_FOR"]
  end

  def append_info_to_payload(payload)
    super
    payload[:ip] = request.headers["CF-Connecting-IP"]
  end

  def handle_unverified_request
    flash[:error] = "CSRF invalid. If you don't know why you're receiving this message, please contact us"
    redirect_to user_root_url
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
      render text: "", content_type: "text/plain"
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

  def locale_from_request_header
    request.env.fetch("HTTP_ACCEPT_LANGUAGE", "").scan(/^[a-z]{2}/).first
  end

  def locale_from_request_params
    requested_locale = params.fetch(:locale, "").strip.to_sym
    requested_locale if I18n.available_locales.include?(requested_locale)
  end

  def set_locale
    logger.debug("* Params: '#{locale_from_request_params}'")
    logger.debug("* User profile:: '#{current_user&.preferred_language}'")
    logger.debug("* Request Headers: '#{locale_from_request_header}'")
    logger.debug("* Default: '#{I18n.default_locale}'")

    I18n.locale =
      locale_from_request_params ||
      current_user&.preferred_language.presence ||
      locale_from_request_header ||
      I18n.default_locale

    logger.debug("* Locale set to '#{I18n.locale}'")
  end
end
