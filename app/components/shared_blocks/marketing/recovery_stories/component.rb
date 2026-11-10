# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module RecoveryStories
      # A marketing section's recovery stories - a row of cards that scrolls sideways on a phone,
      # under the page's heading
      class Component < ApplicationComponent
        def initialize(heading:, recovery_displays:)
          @heading = heading
          @recovery_displays = recovery_displays.first(4)
        end
      end
    end
  end
end
