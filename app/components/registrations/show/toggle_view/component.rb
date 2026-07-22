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
      end
    end
  end
end
