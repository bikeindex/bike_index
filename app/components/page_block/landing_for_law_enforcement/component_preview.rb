# frozen_string_literal: true

module PageBlock::LandingForLawEnforcement
  class ComponentPreview < ApplicationComponentPreview
    # @display kelsey_stylesheet true
    def default
      render(Component.new(recoveries_value: Counts.recoveries_value,
        recoveries: Counts.recoveries, organization_count: Counts.organizations))
    end
  end
end
