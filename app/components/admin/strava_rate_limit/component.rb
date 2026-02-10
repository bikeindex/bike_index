# frozen_string_literal: true

module Admin::StravaRateLimit
  class Component < ApplicationComponent
    def initialize(rate_limit_json:)
      @rate_limit_json = rate_limit_json
    end

    def render?
      @rate_limit_json.present?
    end

    private

    def short_available
      effective_limit("short")
    end

    def short_limit
      effective_total("short")
    end

    def daily_available
      effective_limit("long")
    end

    def daily_limit
      effective_total("long")
    end

    # Use read limits unless the main limit is more restrictive (less available)
    def effective_limit(period)
      main = (@rate_limit_json["#{period}_limit"] || 0) - (@rate_limit_json["#{period}_usage"] || 0)
      read = (@rate_limit_json["read_#{period}_limit"] || 0) - (@rate_limit_json["read_#{period}_usage"] || 0)
      [main, read].min
    end

    def effective_total(period)
      main = @rate_limit_json["#{period}_limit"] || 0
      read = @rate_limit_json["read_#{period}_limit"] || 0
      [main, read].min
    end
  end
end
