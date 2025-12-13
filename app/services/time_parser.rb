# frozen_string_literal: true

# Legacy constant kept for backward compatibility
# Use Binxtils::TimeParser directly for methods
module TimeParser
  DEFAULT_TIME_ZONE = ActiveSupport::TimeZone[Rails.application.class.config.time_zone].freeze

  # Set the gem's default time zone to match Rails config
  Binxtils::TimeParser.default_time_zone = DEFAULT_TIME_ZONE
end
