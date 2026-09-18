# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module RegistrationInformation
        # The card is query-heavy, so each renders a persisted bike the seeds provide, and the
        # preview is gated out of production
        class ComponentPreview < ApplicationComponentPreview
          # @!group Situations
          def staff_with_acknowledgment
            card(acknowledged_bike, "acknowledged e-vehicle")
          end

          def staff_with_sticker
            card(org_bikes.where(id: ::BikeSticker.select(:bike_id)).last, "stickered bike")
          end

          def limited_member
            card(acknowledged_bike, "acknowledged e-vehicle", org_role: :limited)
          end

          def registered_with_another_organization
            card(other_bike, "bike outside the organization")
          end

          def organization_without_features
            card(other_bike, "bike outside the organization",
              organization: ::Organization.new(short_name: "Preview", enabled_feature_slugs: []))
          end
          # @!endgroup

          private

          def card(bike, needed, org_role: :staff, organization: lookbook_organization)
            return production_notice("registration") if Rails.env.production?
            return missing_notice(needed) if bike.blank?

            render(Component.new(bike:, organization:, org_role:))
          end

          def org_bikes
            ::Bike.unscoped.where(id: lookbook_organization.bike_organizations.select(:bike_id))
          end

          def acknowledged_bike
            org_bikes.where(id: ::RegistrationSequenceAcknowledgment.for_organization(lookbook_organization).select(:bike_id)).last
          end

          def other_bike
            ::Bike.where.not(id: org_bikes.select(:id)).last
          end
        end
      end
    end
  end
end
