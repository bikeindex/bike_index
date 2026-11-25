# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module Subtitle
        # The bike's nickname, shown under the bike title
        class Component < ApplicationComponent
          def initialize(bike:)
            @bike = bike
          end

          def render? = @bike.name.present?

          def call = h(translation(".nickname", name: @bike.name))
        end
      end
    end
  end
end
