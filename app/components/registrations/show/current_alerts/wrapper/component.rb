# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module Wrapper
        # The alerts about the registration's current state, rendered above the page
        # body in both the consumer and org admin views. The token-scoped prompts are
        # TokenPrompt's, rendered outside this page's fragment cache
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil, bike_sticker: nil, owner: false)
            @bike = bike
            @current_user = current_user
            @bike_sticker = bike_sticker
            @owner = owner
          end
        end
      end
    end
  end
end
