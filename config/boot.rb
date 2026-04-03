ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Source bin/env for default environment variables (REDIS_URL, DEV_PORT, etc.)
unless ENV["RAILS_ENV"] == "production" || ENV["RACK_ENV"] == "production"
  env_file = File.expand_path("../bin/env", __dir__)
  if File.exist?(env_file)
    `source #{env_file} && env`.each_line do |line|
      key, value = line.strip.split("=", 2)
      ENV[key] ||= value if key && value && !value.empty?
    end
  end
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
