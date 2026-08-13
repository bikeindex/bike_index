# frozen_string_literal: true

module Registrations
  module Show
    module OrgTopActions
      module Wrapper
        # One page stacking every action-button setup. Each variety is an in-memory
        # bike rendered against the persisted lookbook_organization (a featureless
        # org for the no-features case), so nothing is written to the database
        class ComponentPreview < ApplicationComponentPreview
          def default
            render_with_template(template: "registrations/show/org_top_actions/wrapper/preview/default",
              locals: {scenarios:})
          end

          private

          def scenarios
            {
              "With owner" => component(preview_bike(:status_with_owner)),
              "Stolen" => component(stolen_bike),
              "Impounded" => component(impounded_bike),
              "Unregistered parking notification" => component(preview_bike(:unregistered_parking_notification)),
              "With parking notification" => component(bike_with_parking_notification),
              "Limited (non-staff) member" => component(preview_bike(:status_with_owner), org_role: :limited),
              "No features" => component(preview_bike(:status_with_owner), organization: ::Organization.new(short_name: "Preview", enabled_feature_slugs: []))
            }
          end

          def component(bike, org_role: :staff, organization: lookbook_organization)
            Component.new(bike:, organization:, org_role:, current_user: lookbook_user)
          end

          def preview_bike(status)
            ::Bike.new(status:, cycle_type: "bike")
          end

          # Stolen is the one state carried by an association rather than the status
          def stolen_bike
            preview_bike(:status_stolen).tap { |bike| bike.current_stolen_record = ::StolenRecord.new }
          end

          # The update action only shows for the previewing org's own record
          def impounded_bike
            preview_bike(:status_impounded).tap do |bike|
              bike.current_impound_record = ::ImpoundRecord.new(organization_id: lookbook_organization.id, display_id: "0001")
            end
          end

          # A live count and the notification panel are DB queries, so this variety
          # needs a real org bike that already carries a notification
          def bike_with_parking_notification
            notifications = lookbook_organization.parking_notifications
            (notifications.current.last || notifications.last)&.bike ||
              preview_bike(:status_with_owner)
          end
        end
      end
    end
  end
end
