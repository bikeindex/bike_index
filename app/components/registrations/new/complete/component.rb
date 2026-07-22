# frozen_string_literal: true

module Registrations
  module New
    module Complete
      # The completion card: bike created, or awaiting email verification
      class Component < ApplicationComponent
        def initialize(b_param:, bike:)
          @b_param = b_param
          @bike = bike
        end
      end
    end
  end
end
