# frozen_string_literal: true

module Registrations
  module Show
    module OrgTopActions
      module Wrapper
        # Each variety is an in-memory bike rendered against the persisted
        # lookbook_organization, so the action buttons render for every bike
        # state without creating records
        class ComponentPreview < ApplicationComponentPreview
          # Message, create-impound, create-parking, and view-notifications buttons
          def with_owner
            render_scenario(preview_bike(:status_with_owner))
          end

          # Message button comes from the stolen record even when the org can't
          # send unstolen notifications
          def stolen
            bike = preview_bike(:status_stolen)
            bike.current_stolen_record = ::StolenRecord.new
            render_scenario(bike)
          end

          # Swaps the create-impound button for the amber update-impound button
          def impounded
            render_scenario(preview_bike(:status_impounded))
          end

          # No message button (no owner to contact), still impound/parking/view
          def unregistered_parking_notification
            render_scenario(preview_bike(:unregistered_parking_notification))
          end

          # A limited (non-staff) member can't create or update impounds
          def limited_member
            render_scenario(preview_bike(:status_with_owner), staff: false)
          end

          private

          def render_scenario(bike, staff: true)
            render(Component.new(bike:, organization: lookbook_organization, staff:))
          end

          def preview_bike(status)
            ::Bike.new(status:, cycle_type: "bike")
          end
        end
      end
    end
  end
end
