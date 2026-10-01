# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module Wrapper
          # One page per org role, stacking every action-button setup against the persisted
          # lookbook_organization (a featureless org for the no-features case). Nothing is
          # written to the database
          class ComponentPreview < ApplicationComponentPreview
            def staff
              render_scenarios(org_role: :staff)
            end

            def limited
              render_scenarios(org_role: :limited)
            end

            private

            def render_scenarios(org_role:)
              render_with_template(template: "pages/registrations/show/org_top_actions/wrapper/preview/scenarios",
                locals: {scenarios: scenarios(org_role:)})
            end

            def scenarios(org_role:)
              component = ->(bike, organization: lookbook_organization) { Component.new(bike:, organization:, org_role:, current_user: lookbook_user) }
              {
                "With owner" => component.call(organization_bike),
                "With owner not organization registration" => component.call(preview_bike(:status_with_owner)),
                "With owner, notification unstolen off" => component.call(notification_unstolen_off_bike),
                "Stolen" => component.call(stolen_bike),
                "Impounded" => component.call(impounded_bike),
                "Unregistered parking notification" => component.call(preview_bike(:unregistered_parking_notification)),
                "With parking notification" => component.call(bike_with_parking_notification),
                "No features" => component.call(preview_bike(:status_with_owner), organization: ::Organization.new(short_name: "Preview", enabled_feature_slugs: []))
              }
            end

            # An unclaimed bike has no owner to message, and contact_owner? reads one
            def preview_bike(status)
              ::Bike.new(status:, cycle_type: "bike",
                current_ownership: ::Ownership.new(claimed: true, user: lookbook_user))
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

            # organized? plucks bike_organizations, so an in-memory bike can't be registered with the org
            def organization_bike
              lookbook_organization.bikes.status_with_owner.where(is_phone: false)
                .detect { it.contact_owner?(lookbook_user, lookbook_organization) } || preview_bike(:status_with_owner)
            end

            # A real registration, so organized? holds - assigning the belongs_to saves nothing
            def notification_unstolen_off_bike
              organization_bike.tap do |bike|
                bike.current_ownership = ::Ownership.new(claimed: true, user: ::User.new(notification_unstolen: false))
              end
            end

            # A live count and the notification panel are DB queries, so this variety
            # needs a real org bike that already carries a notification
            def bike_with_parking_notification
              notifications = lookbook_organization.parking_notifications.where(unregistered_bike: false)
              (notifications.current.last || notifications.last)&.bike ||
                preview_bike(:status_with_owner)
            end
          end
        end
      end
    end
  end
end
