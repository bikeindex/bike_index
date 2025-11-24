# frozen_string_literal: true

# Configure MiniMagick to ensure ImageMagick is found in all environments
MiniMagick.configure do |config|
  # Explicitly set CLI path if provided
  config.cli_path = ENV["IMAGEMAGICK_PATH"] if ENV["IMAGEMAGICK_PATH"].present?

  # Set timeout for ImageMagick operations (default is 120 seconds)
  config.timeout = 30
end
