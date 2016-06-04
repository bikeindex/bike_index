if Rails.env.production?
  domain = ".bikeindex.org"
else
  domain = "localhost"
end

Bikeindex::Application.config.session_store :cookie_store, key: '_bikeindex_session', domain: domain
