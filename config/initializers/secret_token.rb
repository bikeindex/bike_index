# DEPRECATION WARNING: `secrets.secret_token` is deprecated in favor of
# `secret_key_base` and will be removed in Rails 6.0.
# Bikeindex::Application.config.secret_token = ENV["SESSION_SECRET"]
Bikeindex::Application.config.secret_key_base = ENV["SECRET_KEY_BASE"]
