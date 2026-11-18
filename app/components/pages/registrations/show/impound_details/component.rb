# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module ImpoundDetails
        # Impound location and date for an impounded bike — mirrors the stolen card.
        # When an organization is viewing, it shows the fuller impound-record card
        # with the exact (rather than obscured) location.
        class Component < ApplicationComponent
          def initialize(bike:, organization: nil)
            @bike = bike
            @organization = organization
          end

          def render?
            @bike.status_impounded? && impound_record.present?
          end

          private

          # The fuller impound-record card is for the impounding organization; found-kind
          # records keep the simpler public card
          def org_record?
            @organization.present? && impound_record.organization_id == @organization.id && !found?
          end

          def found?
            @bike.status_found?
          end

          def impound_record
            @impound_record ||= @bike.current_impound_record
          end

          def heading
            return translation(".org_impound_record", org_name: @organization.short_name) if org_record?

            found? ? translation(".found_details") : translation(".impound_details")
          end

          def map_latitude
            org_record? ? impound_record.impounded_from_address&.latitude : impound_record.latitude_public
          end

          def map_longitude
            org_record? ? impound_record.impounded_from_address&.longitude : impound_record.longitude_public
          end

          def map_precise?
            org_record? || impound_record.show_address
          end
        end
      end
    end
  end
end
