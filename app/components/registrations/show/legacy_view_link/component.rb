# frozen_string_literal: true

module Registrations
  module Show
    module LegacyViewLink
      # The redesign's view-preference control. When the viewer has the redesign
      # enabled it's a link back to the classic bike show; when they're only
      # previewing it (the page renders regardless of the flag) it explains that and
      # offers to opt in. Gated on the bike_show_redesign_toggle flag, so only users
      # in the rollout see it. ToggleView is its counterpart on the legacy page.
      class Component < ApplicationComponent
        def initialize(bike:, current_user:)
          @bike = bike
          @current_user = current_user
        end

        def render?
          @current_user.present? && Flipper.enabled?(:bike_show_redesign_toggle, @current_user)
        end

        private

        def redesign_enabled?
          Flipper.enabled?(:bike_show_redesign, @current_user)
        end
      end
    end
  end
end
