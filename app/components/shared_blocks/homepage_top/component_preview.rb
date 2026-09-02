# frozen_string_literal: true

module SharedBlocks
  module HomepageTop
    class ComponentPreview < ApplicationComponentPreview
      # @display kelsey_stylesheet true
      def default
        render(SharedBlocks::HomepageTop::Component.new(recoveries_value: Counts.recoveries_value,
          organization_count: Organization.count, recovery_displays: RecoveryDisplay.limit(5)))
      end
    end
  end
end
