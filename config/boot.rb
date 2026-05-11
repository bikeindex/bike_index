ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Set default environment variables (REDIS_URL, DEV_PORT, etc.) for dev/test
unless ENV["RAILS_ENV"] == "production" || ENV["RACK_ENV"] == "production"
  load File.expand_path("../bin/env", __dir__)
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
