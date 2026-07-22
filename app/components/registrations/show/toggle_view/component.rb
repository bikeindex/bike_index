# frozen_string_literal: true

module Registrations
  module Show
    module ToggleView
      # The "Try out the new view!" invitation shown atop the legacy bike show page.
      # Only for signed-in viewers, since toggling the flag requires a current user.
      # LegacyViewLink is its counterpart on the redesign.
      class Component < ApplicationComponent
        def initialize(bike:, current_user:)
          @bike = bike
          @current_user = current_user
        end

        def render?
          @current_user.present?
        end
      end
    end
  end
end
