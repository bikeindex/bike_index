# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module ParkingNotificationForm
          class ComponentPreview < ApplicationComponentPreview
            # Wrapped in a minimal action-panels accordion so geolocation runs on open,
            # mirroring the org-admin page. An empty panel starts it closed, which is how
            # the system spec drives the accordion
            # @param panel text "Panel to open on load"
            def default(panel: "parking")
              organization = lookbook_organization
              bike = organization.bikes.last || ::Bike.last
              render_with_template(template: "pages/registrations/show/org_top_actions/parking_notification_form/preview/default",
                locals: {bike:, organization:, panel:})
            end
          end
        end
      end
    end
  end
end
