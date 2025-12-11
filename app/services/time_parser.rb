# frozen_string_literal: true

module TimeParser
  DEFAULT_TIME_ZONE = ActiveSupport::TimeZone[Rails.application.class.config.time_zone].freeze

  # Set the gem's default time zone to match Rails config
  BinxUtils::TimeParser.default_time_zone = DEFAULT_TIME_ZONE

  class << self
    delegate :parse, :looks_like_timestamp?, :round, to: "BinxUtils::TimeParser"
  end
end
