# frozen_string_literal: true

module PageBlock::HomepageTop
  class Component < ApplicationComponent
    def initialize(recoveries_value:, organization_count:, recovery_displays:)
      @recoveries_value = recoveries_value
    @organization_count = organization_count
    @recovery_displays = recovery_displays
    end
  end
end
