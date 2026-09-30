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

            def owner_phone
              @bike.phone if @bike.phoneable_by?(@current_user)
            end
          end
        end
      end
    end
  end
end
