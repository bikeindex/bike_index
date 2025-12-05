# frozen_string_literal: true

module PageBlock::HomepageTop
  class ComponentPreview < ApplicationComponentPreview
    # @display redesign_2025_stylesheet true
    def default
      render(PageBlock::HomepageTop::Component.new(recoveries_value: Counts.recoveries_value,
        organization_count: Organization.count, recovery_displays: RecoveryDisplay.limit(5)))
    end
  end
end
