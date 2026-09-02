# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module ParkingNotificationForm
          class ComponentPreview < ApplicationComponentPreview
            # Wrapped in a minimal action-panels accordion so the trigger opens the
            # panel and geolocation runs, mirroring the org-admin page
            def default
              organization = lookbook_organization
              bike = organization.bikes.last || ::Bike.last
              render_with_template(template: "pages/registrations/show/org_top_actions/parking_notification_form/preview/default",
                locals: {bike:, organization:})
            end
          end
        end
      end
    end
  end
end
