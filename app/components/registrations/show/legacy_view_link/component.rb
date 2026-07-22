# frozen_string_literal: true

module Registrations
  module Show
    module LegacyViewLink
      # The counterpart to the legacy page's "Try out the new view!" alert: a link
      # back to the classic bike show. Only shown to signed-in viewers, since
      # toggling the flag off requires a current user.
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
