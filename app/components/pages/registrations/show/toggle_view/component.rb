# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module ToggleView
        # The "Try out the new view!" invitation shown atop the legacy bike show page.
        # LegacyViewLink is its counterpart on the redesign.
        class Component < ApplicationComponent
          def initialize(bike:, current_user:)
            @bike = bike
            @current_user = current_user
          end

          def render?
            @current_user&.registration_show_toggleable?
          end

          private

          # True when the viewer defaults to the redesign and reached the legacy page
          # via no_redesign, so the invitation becomes a "back to new view" prompt.
          def redesign_enabled?
            @current_user.registration_show_redesign?
          end
        end
      end
    end
  end
end
