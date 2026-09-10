# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module Wrapper
        module FinderContact
          # The finder-contact card, rendered on the page it sits in — so this previews the
          # same page as its parent, and inherits how that's built. Only an organization is
          # offered it, so this pins the org view rather than whatever the lookbook user
          # is entitled to
          class ComponentPreview < Wrapper::ComponentPreview
            # @param bike_id text "Bike to render — defaults to a found registration"
            def paid_organization(bike_id: nil)
              bike = preview_bike(bike_id.presence || found_impound&.bike_id)
              return missing_notice("a found registration") if bike.blank?
              return missing_notice("a paid organization to view it as") unless
                ::BikeServices::Displayer.display_found_contact?(bike, lookbook_organization)

              page(bike_id: bike.id, as_view: [:staff, lookbook_organization])
            end

            private

            # An organization's own impound record is an impound rather than a find
            def found_impound
              ::ImpoundRecord.active.unorganized.last
            end
          end
        end
      end
    end
  end
end
