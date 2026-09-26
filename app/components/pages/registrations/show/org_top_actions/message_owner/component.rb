# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module MessageOwner
          # Org-admin panel messaging the owner, as an organization message for the org's own
          # registration or a stolen notification otherwise. Rendered inside the org-admin
          # action-panel accordion (data-panel-name="message")
          class Component < ApplicationComponent
            def initialize(bike:, organization:, current_user: nil)
              @bike = bike
              @organization = organization
              @current_user = current_user
            end

            private

            def organization_message?
              return @organization_message if defined?(@organization_message)

              @organization_message = OrganizationMessage.for?(bike: @bike, organization: @organization)
            end

            # Whoever holds an impounded vehicle already knows where it is, so the
            # sighting the stolen case asks for is the wrong question to put to them
            def impounded?
              @bike.current_impound_record.present?
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
              if impounded?
                translation(".what_do_you_need_to_ask", bike_type: @bike.type)
              else
                translation(".where_did_you_see_this_bike", bike_type: @bike.type)
              end
            end

            def message_notification
              @message_notification ||= StolenNotification.new(bike: @bike)
            end

            # Keyed per bike, so a half-typed message doesn't surface on another bike's form
            def form_data(persist_key)
              {controller: "csrf-refresh form-persist", "form-persist-key-value": "#{persist_key}-#{@bike.id}",
               action: "input->form-persist#save submit->form-persist#clear"}
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
