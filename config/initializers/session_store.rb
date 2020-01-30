domain = Rails.env.production? ? "bikeindex.org" : "localhost"

Rails.application.config.session_store :cookie_store,
  key: '_bikeindex_session',
  domain: domain
