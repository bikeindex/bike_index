domain = if Rails.env.production?
  "bikeindex.org"
elsif Rails.env.test?
  nil
else
  "localhost"
end

# Include port in session key to prevent collisions across Conductor workspaces
key = if Rails.env.production?
  "_bikeindex_session"
else
  port = ENV.fetch("DEV_PORT", 3042)
  "_bikeindex_session_#{port}"
end

Rails.application.config.session_store :cookie_store, key:, domain:
