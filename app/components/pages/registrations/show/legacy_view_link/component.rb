# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module LegacyViewLink
        # The redesign's view-preference control: a link back to the classic bike show,
        # or — for viewers who switched to legacy but reached this page anyway — an
        # offer to switch back. ToggleView is its counterpart on the legacy page.
        class Component < ApplicationComponent
          def initialize(bike:, current_user:)
            @bike = bike
            @current_user = current_user
          end

          def render?
            @current_user&.registration_show_toggleable?
          end

          private

          def redesign_enabled?
            @current_user.registration_show_redesign?
          end
        end
      end
    end
  end
end
