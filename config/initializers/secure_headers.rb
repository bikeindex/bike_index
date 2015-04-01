::SecureHeaders::Configuration.configure do |config|
  config.hsts = {:max_age => 20.years.to_i, :include_subdomains => false}
  config.x_frame_options = 'SAMEORIGIN'
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = false
  config.x_download_options = false
  config.x_permitted_cross_domain_policies = false
  config.csp = false
end