# frozen_string_literal: true

module Pages
  module Org
    module Search
      module SearchAll
        # Targets both searches' controllers, so the search and multi search render the same checkbox.
        # locked_hint says why it's disabled, which differs between them
        class Component < ApplicationComponent
          def initialize(settings:, locked:, locked_hint:)
            @settings = settings
            @locked = locked
            @locked_hint = locked_hint
          end
        end
      end
    end
  end
end
