# frozen_string_literal: true

module Registrations
  module Show
    module Subtitle
      # Year / manufacturer / frame model · colors, shown under the bike title.
      class Component < ApplicationComponent
        def initialize(bike:)
          @bike = bike
        end

        private

        def subtitle
          parts = [@bike.year, BikeServices::Displayer.manufacturer_name(@bike), @bike.frame_model].compact_blank
          [parts.join(" "), @bike.frame_colors.to_sentence].compact_blank.join(" · ")
        end
      end
    end
  end
end
