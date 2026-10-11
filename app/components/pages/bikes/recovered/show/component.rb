# frozen_string_literal: true

module Pages
  module Bikes
    module Recovered
      module Show
        # The recovered bike's welcome home, and the ways to support the next recovery
        class Component < ApplicationComponent
          DONATION_AMOUNTS = [10, 25, 50, 100].freeze
          DEFAULT_DONATION = 25

          def initialize(bike:, stolen_record:)
            @bike = bike
            @stolen_record = stolen_record
          end

          private

          def cycle_type = @bike.type

          def bike_name = @bike.frame_model.presence || @bike.mnfg_name.presence || @bike.type_titleize

          def facebook_url = "https://www.facebook.com/sharer/sharer.php?#{{u: root_url}.to_query}"
        end
      end
    end
  end
end
