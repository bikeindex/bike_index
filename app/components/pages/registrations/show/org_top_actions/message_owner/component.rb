# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module MessageOwner
          # Org-admin panel messaging the owner — an organization message for the org's own
          # registration, otherwise a stolen notification. Rendered inside the org-admin
          # action-panel accordion (data-panel-name="message")
          class Component < ApplicationComponent
            def initialize(bike:, organization:, current_user: nil)
              @bike = bike
              @organization = organization
              @current_user = current_user
            end

            private

            # Whoever holds an impounded vehicle already knows where it is, so the
            # sighting the stolen case asks for is the wrong question to put to them
            def impounded?
              @bike.current_impound_record.present?
            end

            def organization_message?
              return @organization_message if defined?(@organization_message)

              @organization_message = OrganizationMessage.for?(bike: @bike, organization: @organization)
            end

            def heading
              if organization_message?
                translation(".message_the_owner_of_this_bike_type", bike_type: @bike.type)
              elsif impounded?
                translation(".know_who_has_this_bike_type", bike_type: @bike.type)
              else
                translation(".know_something_about_this_bike_type", bike_type: @bike.type)
              end
            end

            def message_placeholder
              if organization_message?
                translation(".what_do_you_want_to_tell_the_owner", bike_type: @bike.type)
              elsif impounded?
                translation(".what_do_you_need_to_ask", bike_type: @bike.type)
              else
                translation(".where_did_you_see_this_bike", bike_type: @bike.type)
              end
            end

            # A phone registration has no email to send an organization message to
            def message_form?
              !(organization_message? && @bike.phone_registration?)
            end

            def message_record
              organization_message? ? OrganizationMessage.new : StolenNotification.new
            end

            def message_url
              if organization_message?
                organization_organization_messages_path(organization_id: @organization.to_param)
              else
                stolen_notifications_path
              end
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
