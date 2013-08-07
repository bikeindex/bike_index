if Rails.env.production?
  domain = ".bikeindex.org"
else
  domain = ".lvh.me"
  # domain = ".bikeindex.dev"
end

Bikeindex::Application.config.session_store :cookie_store, key: '_bikeindex_session', domain: domain
