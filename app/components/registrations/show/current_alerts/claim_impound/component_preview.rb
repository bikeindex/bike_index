# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module ClaimImpound
        # One scenario per state the card reaches. The component reads the impound record
        # and the viewer's claim off the database rather than taking them as arguments, so
        # these render real records — and are gated out of production, where they'd be
        # someone's actual claim
        class ComponentPreview < ApplicationComponentPreview
          # Signed out, so the claim button routes through sign-in
          def signed_out
            card(bike: claimable_impound&.bike, current_user: nil)
          end

          # Signed in with no stolen registration to claim it with
          def no_stolen_bike
            impound = claimable_impound
            card(bike: impound&.bike, current_user: user_without_stolen_bike(impound))
          end

          # The open-claim form, listing the viewer's stolen bikes
          def open_claim
            impound = claimable_impound
            card(bike: impound&.bike, current_user: unclaimed_viewer(impound))
          end

          # Opened but not sent — the message is still editable
          def claim_unsubmitted
            claim_card(::ImpoundClaim.not_rejected.unsubmitted)
          end

          def claim_submitted
            claim_card(::ImpoundClaim.not_rejected.submitted.where.not(status: successful_statuses))
          end

          def claim_approved
            claim_card(::ImpoundClaim.submitted.where(status: successful_statuses))
          end

          # Viewing the stolen registration a claim was opened with, which points at the
          # impounded one rather than offering a claim of its own
          def submitted_with_this_bike
            claim = ::ImpoundClaim.not_rejected.where.not(bike_submitting_id: nil).last
            return missing_notice("an impound claim") if claim.blank?

            card(bike: claim.bike_submitting, current_user: claim.user)
          end

          private

          def successful_statuses = ::ImpoundClaim.successful_statuses

          def claim_card(claims)
            claim = claims.where.not(bike_claimed_id: nil).last
            return missing_notice("a matching impound claim") if claim.blank?

            card(bike: claim.bike_claimed, current_user: claim.user)
          end

          # A card that won't render says so, rather than previewing as a blank page
          def card(bike:, current_user:)
            return production_notice if Rails.env.production?
            return missing_notice("a claimable impound record") if bike.blank?

            component = Component.new(bike: bike.reload, current_user:)
            return missing_notice("the records this scenario needs") unless component.render?

            render(component)
          end

          def claimable_impound
            @claimable_impound ||= ::ImpoundRecord.active.unorganized.last
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

          def production_notice
            render(UI::Alert::Component.new(kind: :error,
              text: "This preview renders a real impound claim, so it's disabled in production."))
          end

          def missing_notice(needed)
            render(UI::Alert::Component.new(kind: :warning,
              text: "Nothing to preview — this environment has no #{needed}."))
          end
        end
      end
    end
  end
end
