# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      module ClaimImpound
        # What every claim-impound preview needs: the page, and the records that raise the
        # card on it. The card is only ever offered to someone who isn't the owner, so
        # these pin the public view rather than whatever the lookbook user is entitled to
        module PreviewScenarios
          include PreviewPage

          private

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
        end
      end
    end
  end
end
