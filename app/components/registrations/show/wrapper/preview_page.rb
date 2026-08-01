# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      # Renders the whole registration show page for a preview. Shared by the overlay
      # scenarios and the ClaimImpound:: previews, which each raise a different alert
      # over the same page
      module PreviewPage
        private

        # The block builds the alerts off the resolved bike, or returns :missing.
        # as_view pins the perspective for a scenario that only makes sense in one
        def page(view:, bike_id:, bike_sticker: nil, current_user: lookbook_user, as_view: nil)
          return production_notice("registration") if Rails.env.production?

          bike = preview_bike(bike_id)
          return missing_notice("a bike") if bike.blank?

          current_alerts = block_given? ? yield(bike) : {}
          return missing_notice("the record this scenario needs") if current_alerts == :missing

          available_views = ::BikeServices::ShowViews.available(bike:, current_user:,
            organization: lookbook_organization)
          resolved = as_view || resolved_view(view, available_views, bike:, current_user:)
          component = Component.new(bike:, current_user:, view: resolved, available_views:,
            bike_sticker:, current_alerts:)

          render_with_template(template: "registrations/show/wrapper/preview/scenario",
            locals: {component:, offset_header: resolved.last.nil?})
        end

        # ShowViews decides what this viewer may see; the param only picks which side of
        # that to show, so a preview can't put up a page the app never serves
        def resolved_view(view, available_views, bike:, current_user:)
          org_view = view.to_s == "org_admin"
          available_views.find { |_kind, organization| organization.present? == org_view } ||
            ::BikeServices::ShowViews.default_view_for(bike:, current_user:, organization: lookbook_organization)
        end

        # Claimed by default — SentToNewOwner raises itself off an unclaimed registration,
        # stacking that alert onto every other scenario
        def preview_bike(bike_id)
          ::Bike.unscoped.find_by(id: bike_id) || bike_with_ownership(claimed: true)
        end

        def bike_with_ownership(claimed:)
          owned = ::Ownership.current.where(claimed:).select(:bike_id)
          org_bikes.where(id: owned).last || ::Bike.unscoped.where(id: owned).last
        end

        def org_bikes
          lookbook_organization&.bikes || ::Bike.none
        end
      end
    end
  end
end
