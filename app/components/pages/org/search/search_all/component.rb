# frozen_string_literal: true

module Pages
  module Org
    module Search
      module SearchAll
        # Targets both searches' controllers, so the search and multi search render the same checkbox.
        # locked_hints says why it's disabled, by each reason the search can have - lock is the one
        # in force
        class Component < ApplicationComponent
          def initialize(settings:, locked_hints:, lock: nil)
            @settings = settings
            @locked_hints = locked_hints
            @lock = lock
          end
        end
      end
    end
  end
end
