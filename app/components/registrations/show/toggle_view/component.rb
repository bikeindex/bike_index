# frozen_string_literal: true

module Registrations
  module Show
    module ToggleView
      # The "Try out the new view!" invitation shown atop the legacy bike show page.
      # Gated on the bike_show_redesign_toggle flag, so only users included in the
      # rollout see the opt-in. LegacyViewLink is its counterpart on the redesign.
      class Component < ApplicationComponent
        def initialize(bike:, current_user:)
          @bike = bike
          @current_user = current_user
        end

        def render?
          @current_user.present? && Flipper.enabled?(:bike_show_redesign_toggle, @current_user)
        end

        private

        # True when the viewer defaults to the redesign and reached the legacy page
        # via no_redesign, so the invitation becomes a "back to new view" prompt.
        def redesign_enabled?
          Flipper.enabled?(:bike_show_redesign, @current_user)
        end
      end
    end
  end
end
