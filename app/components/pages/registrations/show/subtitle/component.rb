# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module Subtitle
        # Year / frame model · colors, shown under the bike title.
        class Component < ApplicationComponent
          def initialize(bike:)
            @bike = bike
          end

          def call
            parts = [@bike.year, @bike.frame_model].compact_blank
            safe_join([parts.join(" "), @bike.frame_colors.to_sentence].compact_blank, " · ")
          end
        end
      end
    end
  end
end
