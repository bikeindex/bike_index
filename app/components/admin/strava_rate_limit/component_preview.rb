# frozen_string_literal: true

module Admin::StravaRateLimit
  class ComponentPreview < ApplicationComponentPreview
    # @group amount Variants
    def high_rate_limit
      render(Admin::StravaRateLimit::Component.new(rate_limit_json: high_rate_limit_json))
    end

    def medium_rate_limit
      render(Admin::StravaRateLimit::Component.new(rate_limit_json: medium_rate_limit_json))
    end

    def low_rate_limit
      render(Admin::StravaRateLimit::Component.new(rate_limit_json: low_rate_limit_json))
    end
    # @endgroup

    private

    def high_rate_limit_json
      {
        long_limit: 6000,
        long_usage: 3,
        short_limit: 600,
        short_usage: 1,
        read_long_limit: 3000,
        read_long_usage: 3,
        read_short_limit: 300,
        read_short_usage: 1
      }.as_json
    end

    def medium_rate_limit_json
      {
        long_limit: 6000,
        long_usage: 3,
        short_limit: 600,
        short_usage: 1,
        read_long_limit: 3000,
        read_long_usage: 3,
        read_short_limit: 300,
        read_short_usage: 1
      }.as_json
    end

    def low_rate_limit_json
      {
        long_limit: 6000,
        long_usage: 3,
        short_limit: 600,
        short_usage: 1,
        read_long_limit: 3000,
        read_long_usage: 3,
        read_short_limit: 300,
        read_short_usage: 1
      }.as_json
    end
  end
end
