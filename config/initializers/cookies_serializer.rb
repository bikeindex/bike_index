# Be sure to restart your server when you modify this file.

# Specify a serializer for the signed and encrypted cookie jars.
# Valid options are :json, :marshal, and :hybrid.

# Set to hybrid because it was set to hybrid prior to 5.1
# See: https://github.com/rails/rails/issues/33580
Rails.application.config.action_dispatch.cookies_serializer = :hybrid
