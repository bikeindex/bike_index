# frozen_string_literal: true

module UI
  module Forms
    module LegacyFormWell
      module AddressRecord
        class ComponentPreview < ApplicationComponentPreview
          layout "component_preview_form_wrap"

          # @param organization_id text "Organization ID to render the fields for"
          def default(organization_id: nil)
            organization = Organization.friendly_find(organization_id)
            user = User.new
            user.address_record = ::AddressRecord.new(country: organization&.country || Country.united_states, user:)

            {template: "ui/forms/legacy_form_well/address_record/component_preview/default",
             locals: {organization:, user:}}
          end

          def impounded_bike
            bike = Bike.new(status: "status_impounded")
            bike.impound_records.build(address_record: ::AddressRecord.new(country: Country.united_states))

            {template: "ui/forms/legacy_form_well/address_record/component_preview/default",
             locals: {bike:}}
          end

          # TODO: WTF, why isn't the @param working :/
          # def with_organization
          # end

          # def with_organization_with_all_helpers
          # end
        end
      end
    end
  end
end
