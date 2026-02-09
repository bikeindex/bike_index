# frozen_string_literal: true

module Admin::StravaRateLimit
  class Component < ApplicationComponent
    def initialize(rate_limit_json:)
      @rate_limit_json = rate_limit_json
    end
  end
end
