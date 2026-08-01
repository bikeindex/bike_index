# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      # The whole registration show page, one scenario per overlay it can raise. These
      # render a persisted bike — the page is far too query-heavy for an in-memory one — so
      # they're gated out of production, where the bikes would be someone's real ones
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

        # The claim card is only ever offered to someone who isn't the owner, so every
        # claim_impound scenario previews the public view rather than whatever the
        # lookbook user is entitled to, and resolves the viewer the state needs
        # @param bike_id text "Bike to render — defaults to a claimable found one"
        def claim_impound(bike_id: nil)
          impound = claimable_impound
          claim_page(bike_id: bike_id.presence || impound&.bike_id, current_user: unclaimed_viewer(impound))
        end

        # @param bike_id text "Bike to render — defaults to a claimable found one"
        def claim_impound_signed_out(bike_id: nil)
          claim_page(bike_id: bike_id.presence || claimable_impound&.bike_id, current_user: nil)
        end

        # @param bike_id text "Bike to render — defaults to a claimable found one"
        def claim_impound_no_stolen_bike(bike_id: nil)
          impound = claimable_impound
          claim_page(bike_id: bike_id.presence || impound&.bike_id,
            current_user: user_without_stolen_bike(impound))
        end

        # Opened but not sent — the message is still editable
        def claim_impound_unsubmitted
          claim_page_for(::ImpoundClaim.not_rejected.unsubmitted)
        end

        def claim_impound_submitted
          claim_page_for(::ImpoundClaim.not_rejected.submitted.where.not(status: ::ImpoundClaim.successful_statuses))
        end

        def claim_impound_approved
          claim_page_for(::ImpoundClaim.submitted.where(status: ::ImpoundClaim.successful_statuses))
        end

        # Viewing the stolen registration a claim was opened with, which points at the
        # impounded one rather than offering a claim of its own
        def claim_impound_submitted_with_this_bike
          claim = ::ImpoundClaim.not_rejected.where.not(bike_submitting_id: nil).last
          return missing_notice("an impound claim") if claim.blank?

          claim_page(bike_id: claim.bike_submitting_id, current_user: claim.user)
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

        # A page whose card won't render says so, rather than previewing as one without it
        def claim_page(bike_id:, current_user:)
          bike = ::Bike.unscoped.find_by(id: bike_id)
          return missing_notice("a found registration to claim") if bike.blank?
          return missing_notice("the records this scenario needs") unless
            ::BikeServices::Displayer.display_impound_claim?(bike, current_user)

          page(view: "consumer", bike_id:, current_user:, as_view: [:public, nil])
        end

        def claim_page_for(claims)
          claim = claims.where.not(bike_claimed_id: nil).last
          return missing_notice("a matching impound claim") if claim.blank?

          claim_page(bike_id: claim.bike_claimed_id, current_user: claim.user)
        end

        # An organization's impound record can't be claimed, so only unorganized ones
        # raise the card
        def claimable_impound
          ::ImpoundRecord.active.unorganized.last
        end

        # Claiming needs a stolen registration, and the owner is never offered a claim
        def unclaimed_viewer(impound)
          already_claimed = impound&.impound_claims&.pluck(:user_id) || []
          stolen_bike_owners.find { |user| user != impound&.bike&.owner && already_claimed.exclude?(user.id) }
        end

        def user_without_stolen_bike(impound)
          ::User.where.not(id: stolen_bike_owners.map(&:id) + [impound&.bike&.owner&.id].compact).first
        end

        def stolen_bike_owners
          @stolen_bike_owners ||= ::Bike.status_stolen.reorder(id: :desc).limit(50).filter_map(&:user).uniq
        end

        def bike_with_ownership(claimed:)
          owned = ::Ownership.current.where(claimed:).select(:bike_id)
          org_bikes.where(id: owned).last || ::Bike.unscoped.where(id: owned).last
        end
      end
    end
  end
end
