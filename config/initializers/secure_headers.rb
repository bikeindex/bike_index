::SecureHeaders::Configuration.configure do |config|
  config.hsts = "max-age=#{20.years.to_i}; preload"
  config.x_frame_options = 'SAMEORIGIN'
  config.x_content_type_options = 'nosniff'
  config.x_frame_options = 'ALLOWALL'
  config.x_download_options = nil
  config.x_permitted_cross_domain_policies = 'none'
  # config.csp = false
end