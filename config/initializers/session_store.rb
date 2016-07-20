domain = Rails.env.production? ? 'bikeindex.org' : 'localhost'

Bikeindex::Application.config.session_store :cookie_store, key: '_bikeindex_session', domain: domain
