# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module MessageOwner
          # Org-admin panel messaging the owner via a stolen notification — or, for the org's
          # own registration, an organization message, with a toggle to send a stolen one
          # instead. Rendered inside the org-admin action-panel accordion (data-panel-name="message")
          class Component < ApplicationComponent
            def initialize(bike:, organization:, current_user: nil)
              @bike = bike
              @organization = organization
              @current_user = current_user
              # A phone registration has no email to send an organization message to
              @organization_message = OrganizationMessage.for?(bike:, organization:) &&
                OrganizationMessage.receiver_email_for(bike).present?
            end

            private

            # Whoever holds an impounded vehicle already knows where it is, so the
            # sighting the stolen case asks for is the wrong question to put to them
            def impounded?
              @bike.current_impound_record.present?
            end

            def heading
              if @organization_message
                translation(".message_the_owner_of_this_bike_type", bike_type: @bike.type)
              elsif impounded?
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
