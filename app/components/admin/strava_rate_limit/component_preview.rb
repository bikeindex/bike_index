# frozen_string_literal: true

module Admin::StravaRateLimit
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Admin::StravaRateLimit::Component.new(rate_limit_json:))
    end
  end
end
