# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module Wrapper
        module ContactImpound
          # The contact-impound card, rendered on the page it sits in — so this previews
          # the same page as its parent. Only a viewer whose organization is trusted to
          # message without claiming is offered it, so these resolve that viewer rather
          # than whatever the lookbook user is entitled to
          class ComponentPreview < Wrapper::ComponentPreview
            # A find, where whoever registered it is the one being messaged
            # @param bike_id text "Bike to render — defaults to a found registration"
            def found(bike_id: nil)
              contact_page(bike_id: bike_id.presence || found_impound&.bike_id)
            end

            # An organization's own impound, which labels the button for the owner instead
            # @param bike_id text "Bike to render — defaults to an organized impound"
            def impounded(bike_id: nil)
              contact_page(bike_id: bike_id.presence || organized_impound&.bike_id)
            end

            private

            # A page whose card won't render says so, rather than previewing as one
            # without it
            def contact_page(bike_id:)
              bike = preview_bike(bike_id)
              return missing_notice("an impounded registration") if bike.blank?

              viewer = contactable_viewer(bike.current_impound_record)
              return missing_notice("a member of an organization trusted to message without claiming") if viewer.blank?

              page(bike_id: bike.id, current_user: viewer, as_view: [:public, nil])
            end

            def found_impound
              ::ImpoundRecord.active.unorganized.last
            end

            def organized_impound
              ::ImpoundRecord.active.organized.last
            end

            # Asks the record the same question the card does, rather than rebuilding its
            # three-way allowance here
            def contactable_viewer(impound_record)
              return if impound_record.blank?

              ::User.where(id: ::OrganizationRole.select(:user_id)).limit(25)
                .find { |user| impound_record.contactable_without_claiming?(user) }
            end
          end
        end
      end
    end
  end
end
