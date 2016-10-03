class ApplicationController < ActionController::Base
  include ControllerHelpers
  protect_from_forgery

  ensure_security_headers(csp: false,
    hsts: "max-age=#{20.years.to_i}",
    x_frame_options: 'SAMEORIGIN',
    x_content_type_options: 'nosniff',
    x_xss_protection: false,
    x_download_options: false,
    x_permitted_cross_domain_policies: false)

  def forwarded_ip_address
    request.env['HTTP_X_FORWARDED_FOR'].split(',')[0] if request.env['HTTP_X_FORWARDED_FOR']
  end

  def append_info_to_payload(payload)
    super
    payload[:ip] = request.headers['CF-Connecting-IP']
  end

  def handle_unverified_request
    flash[:error] = "CSRF invalid. If you weren't intentionally doing something dumb, please contact us"
    redirect_to user_root_url
  end

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, PUT, GET, OPTIONS'
    headers['Access-Control-Request-Method'] = '*'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
    headers['Access-Control-Max-Age'] = "1728000"
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
