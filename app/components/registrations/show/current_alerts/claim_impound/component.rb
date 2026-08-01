# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module ClaimImpound
        # "Does this look like your bike?" — lets a non-owner open an impound claim
        # against one of their stolen bikes, then shows that claim once it exists.
        # Mirrors the contact-owner card.
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil, owner: false, organization: nil)
            @bike = bike
            @current_user = current_user
            @owner = owner
            @organization = organization
          end

          # An organization's staff panel isn't asking whether the bike is theirs
          def render?
            return false if @owner || @organization.present?

            BikeServices::Displayer.display_impound_claim?(@bike, @current_user)
          end

          private

          def heading
            translation((claim || submitting_claim) ? ".your_claim" : ".does_this_look_like_your_bike")
          end

          def claim_button_text
            translation(@bike.status_found? ? ".claim_found_bike" : ".claim_impounded_bike")
          end

          def impound_record
            @impound_record ||= @bike.current_impound_record
          end

          # The viewer's claim against this bike, once they've opened one
          def claim
            return @claim if defined?(@claim)

            @claim = viewer_claim(@bike.impound_claims_claimed)
          end

          # A claim the viewer opened with this bike - they're looking at the stolen bike
          # they submitted rather than the impounded one being claimed
          def submitting_claim
            return if claim.present?
            return @submitting_claim if defined?(@submitting_claim)

            @submitting_claim = viewer_claim(@bike.impound_claims_submitting)
          end

          def viewer_claim(claims)
            return if @current_user.blank?

            claims.where(user_id: @current_user.id).not_rejected.last
          end

          def new_claim
            @new_claim ||= ImpoundClaim.new
          end

          # The viewer's stolen bikes they could claim this impound with
          def stolen_record_options
            claimable_bikes.map { |bike| [bike.title_string, bike.current_stolen_record&.id] }
          end

          def claimable_bikes
            @claimable_bikes ||= @current_user&.bikes&.status_stolen&.reorder(created_at: :desc)&.limit(10) || []
          end

          # Logged-out viewers are sent to sign-in and returned with the claim open
          def sign_in_redirect
            return if @current_user.present?

            new_session_path(return_to: registration_path(@bike, contact_owner: true))
          end
        end
      end
    end
  end
end
