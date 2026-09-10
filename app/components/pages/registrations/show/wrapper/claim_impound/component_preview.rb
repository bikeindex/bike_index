# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module Wrapper
        module ClaimImpound
          # One scenario per state the claim-impound card reaches, rendered on the page it
          # sits in — so this previews the same page as its parent, and inherits how that's
          # built. The card is only ever offered to someone who isn't the owner, so these
          # pin the public view rather than whatever the lookbook user is entitled to
          class ComponentPreview < Wrapper::ComponentPreview
            # The viewer has a stolen registration to claim the found bike with
            # @param bike_id text "Bike to render — defaults to a claimable found one"
            def with_stolen_registration(bike_id: nil)
              viewer = unclaimed_viewer or return missing_notice("viewer who could claim this")
              claim_page(bike_id:, current_user: viewer)
            end

            # Signed out, so the claim button routes through sign-in
            # @param bike_id text "Bike to render — defaults to a claimable found one"
            def signed_out(bike_id: nil)
              claim_page(bike_id:, current_user: nil)
            end

            # Signed in with nothing to claim the found bike with
            # @param bike_id text "Bike to render — defaults to a claimable found one"
            def without_stolen_registration(bike_id: nil)
              viewer = user_without_stolen_bike or return missing_notice("viewer without a stolen registration")
              claim_page(bike_id:, current_user: viewer)
            end

            # Opened but not sent — the message is still editable
            def unsubmitted
              claim_page_for(::ImpoundClaim.not_rejected.unsubmitted)
            end

            # Sent, and waiting on the finder
            def submitted
              claim_page_for(::ImpoundClaim.not_rejected.submitted.where.not(status: ::ImpoundClaim.successful_statuses))
            end

            # Answered, so the card carries the outcome rather than a form
            def approved
              claim_page_for(::ImpoundClaim.submitted.where(status: ::ImpoundClaim.successful_statuses))
            end

            # Viewing the stolen registration a claim was opened with, which points at the
            # impounded one rather than offering a claim of its own
            def submitted_with_this_bike
              impound_claim = ::ImpoundClaim.not_rejected.where.not(bike_submitting_id: nil).last
              return missing_notice("an impound claim") if impound_claim.blank?

              claim_page(bike_id: impound_claim.bike_submitting_id, current_user: impound_claim.user)
            end

            private

            # Defaults to the found registration the states without a claim of their own
            # are about. A page whose card won't render says so, rather than previewing as
            # one without it
            def claim_page(current_user:, bike_id: nil)
              bike = preview_bike(bike_id.presence || claimable_impound&.bike_id)
              return missing_notice("a found registration to claim") if bike.blank?
              return missing_notice("the records this scenario needs") unless
                ::BikeServices::Displayer.display_impound_claim?(bike, current_user)

              page(bike_id: bike.id, current_user:, as_view: [:public, nil])
            end

            def claim_page_for(impound_claims)
              impound_claim = impound_claims.where.not(bike_claimed_id: nil).last
              return missing_notice("a matching impound claim") if impound_claim.blank?

              claim_page(bike_id: impound_claim.bike_claimed_id, current_user: impound_claim.user)
            end

            # An organization's impound record can't be claimed, so only unorganized ones
            # raise the card
            def claimable_impound
              return @claimable_impound if defined?(@claimable_impound)

              @claimable_impound = ::ImpoundRecord.active.unorganized.last
            end

            # Claiming needs a stolen registration, and the owner is never offered a claim
            def unclaimed_viewer
              already_claimed = claimable_impound&.impound_claims&.pluck(:user_id) || []
              stolen_bike_owners.find { |user| user != impound_owner && already_claimed.exclude?(user.id) }
            end

            def user_without_stolen_bike
              ::User.where.not(id: stolen_bike_owners.map(&:id) + [impound_owner&.id].compact).first
            end

            def impound_owner
              claimable_impound&.bike&.owner
            end

            def stolen_bike_owners
              @stolen_bike_owners ||= ::Bike.status_stolen.includes(current_ownership: :user)
                .reorder(id: :desc).limit(50).filter_map(&:user).uniq
            end
          end
        end
      end
    end
  end
end
