# frozen_string_literal: true

module Registrations
  module Show
    module OrgTopActionsMessageOwner
      # Org-admin "Know something about this bike?" panel — messages the owner via
      # a stolen/unstolen notification. Rendered inside the org-admin action-panel
      # accordion (data-panel-name="message")
      class Component < ApplicationComponent
        def initialize(bike:)
          @bike = bike
        end

        private

        def message_notification
          @message_notification ||= StolenNotification.new(bike: @bike)
        end
      end
    end
  end
end
