ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Set default environment variables (REDIS_URL, DEV_PORT, etc.) for dev/test only —
# deployed environments (production, staging) provide their own.
deployed = %w[production staging]
unless deployed.include?(ENV["RAILS_ENV"]) || deployed.include?(ENV["RACK_ENV"])
  load File.expand_path("../bin/env", __dir__)
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
