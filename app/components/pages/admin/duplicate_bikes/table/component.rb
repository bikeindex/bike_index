# frozen_string_literal: true

module Pages
  module Admin
    module DuplicateBikes
      module Table
        # The serial-segment DuplicateBikeGroups list. segments: each group's shared segment by ID,
        # statistics: its record, serial, manufacturer and stolen counts
        class Component < ApplicationComponent
          def initialize(groups:, segments:, statistics:)
            @groups = groups
            @segments = segments
            @statistics = statistics
          end
        end
      end
    end
  end
end
