# frozen_string_literal: true

module Registrations
  module Show
    module OrgTopActions
      module MessageOwner
        # Org-admin "Know something about this bike?" panel — messages the owner via
        # a stolen/unstolen notification. Rendered inside the org-admin action-panel
        # accordion (data-panel-name="message")
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil)
            @bike = bike
            @current_user = current_user
          end

          private

          def message_notification
            @message_notification ||= StolenNotification.new(bike: @bike)
          end

          def owner_phone
            @bike.phone if @bike.phoneable_by?(@current_user)
          end
        end
      end
    end
  end
end
