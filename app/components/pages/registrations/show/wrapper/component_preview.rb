# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module Wrapper
        # The whole registration show page, one scenario per overlay it can raise. These
        # render a persisted bike — the page is far too query-heavy for an in-memory one — so
        # they're gated out of production, where the bikes would be someone's real ones.
        # The claim-impound card's states preview from ClaimImpound::ComponentPreview,
        # which inherits #page from here
        class ComponentPreview < ApplicationComponentPreview
          # @param view select [consumer, org_admin]
          # @param bike_id text "Bike to render — defaults to one of the org's"
          def no_overlay(view: "consumer", bike_id: nil)
            page(view:, bike_id:)
          end

          # @param view select [consumer, org_admin]
          # @param bike_id text "Bike to render — defaults to one of the org's"
          def claim_invitation(view: "consumer", bike_id: nil)
            page(view:, bike_id:) { {claim_message: "new_registration"} }
          end

          # The recipient usually has no account yet, so this is the one most of them see
          # @param view select [consumer, org_admin]
          # @param bike_id text "Bike to render — defaults to one of the org's"
          def claim_invitation_signed_out(view: "consumer", bike_id: nil)
            page(view:, bike_id:, current_user: nil) { {claim_message: "new_registration"} }
          end

          # @param view select [consumer, org_admin]
          # @param bike_id text "Bike to render — defaults to one of the org's"
          def notification_token(view: "consumer", bike_id: nil)
            page(view:, bike_id:) do |bike|
              notification = parking_notification(bike) or next :missing
              {token: notification.retrieval_link_token, token_type: notification.kind,
               matching_notification: notification}
            end
          end

          # @param view select [consumer, org_admin]
          # @param bike_id text "Bike to render — defaults to one of the org's"
          def graduated_notification(view: "consumer", bike_id: nil)
            page(view:, bike_id:) do |bike|
              notification = graduated_notification_for(bike) or next :missing
              {token: notification.marked_remaining_link_token,
               token_type: "graduated_notification", matching_notification: notification}
            end
          end

          # @param view select [consumer, org_admin]
          # @param bike_id text "Bike to render — defaults to one of the org's"
          def recovery_prompt(view: "consumer", bike_id: nil)
            page(view:, bike_id:) do |bike|
              # Not the bike's own record: a stolen registration here is an unclaimed one,
              # which would stack SentToNewOwner's alert on top of the prompt being previewed
              stolen_record = bike.current_stolen_record || ::StolenRecord.unscoped.last or next :missing
              {recovered_stolen_record: stolen_record}
            end
          end

          # @param view select [consumer, org_admin]
          # @param bike_id text "Bike to render — defaults to one of the org's"
          def scanned_sticker(view: "consumer", bike_id: nil)
            sticker = bike_sticker(bike_id)
            return missing_notice("a bike sticker assigned to a bike") if sticker.blank?

            page(view:, bike_id:, bike_sticker: sticker)
          end

          # @param view select [consumer, org_admin]
          # @param bike_id text "Bike to render — defaults to one awaiting a claim"
          def sent_to_new_owner(view: "consumer", bike_id: nil)
            # State rather than a token, so it needs an unclaimed ownership and the owner
            page(view:, bike_id: bike_id.presence || bike_with_ownership(claimed: false)&.id)
          end

          private

          # The block builds the alerts off the resolved bike, or returns :missing.
          # as_view pins the perspective for a scenario that only makes sense in one
          def page(bike_id:, view: nil, bike_sticker: nil, current_user: lookbook_user, as_view: nil)
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

            render_with_template(template: "pages/registrations/show/wrapper/preview/scenario",
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

          def parking_notification(bike)
            sent = ::ParkingNotification.where.not(retrieval_link_token: nil)
            sent.where(bike_id: bike.id).last || sent.where(organization_id: lookbook_organization&.id).last || sent.last
          end

          def graduated_notification_for(bike)
            ::GraduatedNotification.where(bike_id: bike.id).last || ::GraduatedNotification.last
          end

          def bike_sticker(bike_id)
            assigned = ::BikeSticker.where.not(bike_id: nil)
            (bike_id.present? ? assigned.where(bike_id:).last : nil) || assigned.last
          end
        end
      end
    end
  end
end
