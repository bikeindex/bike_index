domain = Rails.env.production? ? "bikeindex.org" : "localhost"

# Include port in session key to prevent collisions across Conductor workspaces
session_key = if Rails.env.production?
  "_bikeindex_session"
else
  port = ENV.fetch("DEV_PORT", 3042)
  "_bikeindex_session_#{port}"
end

Rails.application.config.session_store :cookie_store,
  key: session_key,
  domain: domain
