# frozen_string_literal: true

module Pages
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

            # Whoever holds an impounded vehicle already knows where it is, so the
            # sighting the stolen case asks for is the wrong question to put to them
            def impounded?
              @bike.current_impound_record.present?
            end

            def heading
              if impounded?
                translation(".know_who_has_this_bike_type", bike_type: @bike.type)
              else
                translation(".know_something_about_this_bike_type", bike_type: @bike.type)
              end
            end

            def message_placeholder
              if impounded?
                translation(".what_do_you_need_to_ask", bike_type: @bike.type)
              else
                translation(".where_did_you_see_this_bike", bike_type: @bike.type)
              end
            end

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
end
