# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module SentToNewOwner
          # Shown to the sender while the registration is waiting on the new owner's claim
          class Component < ApplicationComponent
            def initialize(bike:, owner: false)
              @bike = bike
              @owner = owner
            end

            def render?
              @owner && @bike.current_ownership.present? && !@bike.claimed?
            end
          end
        end
      end
    end
  end
end
