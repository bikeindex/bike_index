SecureHeaders::Configuration.default do |config|
  config.csp = SecureHeaders::OPT_OUT
  config.hsts = "max-age=#{20.years.to_i}"
  config.x_frame_options = "SAMEORIGIN"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = SecureHeaders::OPT_OUT
  config.x_download_options = SecureHeaders::OPT_OUT
  config.x_permitted_cross_domain_policies = SecureHeaders::OPT_OUT
end
