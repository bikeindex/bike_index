# frozen_string_literal: true

module Pages
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
              return false if hidden_from_viewer?

              BikeServices::Displayer.display_impound_claim?(@bike, @current_user)
            end

            # This renders the viewer's own claim, which nothing else in the page's cache key
            # moves when they save or submit it. Guarded rather than gated on render?, which
            # would cost queries of its own on the pages that have no claim to show
            def cache_version
              return [] if hidden_from_viewer? || @current_user.blank?

              [ImpoundClaim.involving_bike_id(@bike.id).where(user_id: @current_user.id).maximum(:updated_at)]
            end

            private

            def hidden_from_viewer?
              @owner || @organization.present?
            end

            def heading
              return translation(".your_claim") if shown_impound_claim

              translation(".does_this_look_like_your_bike", bike_type: @bike.type)
            end

            # An answered claim is good news; everything else is still waiting on somebody
            def alert_kind
              shown_impound_claim&.successful? ? :success : :warning
            end

            # Whichever side of the claim this bike is - the impound being claimed, or the
            # stolen registration it was claimed with
            def shown_impound_claim
              impound_claim || submitting_impound_claim
            end

            def claim_button_text
              translation(@bike.status_found? ? ".claim_found_bike" : ".claim_impounded_bike",
                bike_type: @bike.type)
            end

            def impound_record
              @impound_record ||= @bike.current_impound_record
            end

            # The viewer's claim against this bike, once they've opened one
            def impound_claim
              return @impound_claim if defined?(@impound_claim)

              @impound_claim = viewer_impound_claim(@bike.impound_claims_claimed)
            end

            # A claim the viewer opened with this bike - they're looking at the stolen bike
            # they submitted rather than the impounded one being claimed
            def submitting_impound_claim
              return @submitting_impound_claim if defined?(@submitting_impound_claim)

              @submitting_impound_claim = viewer_impound_claim(@bike.impound_claims_submitting)
            end

            def viewer_impound_claim(impound_claims)
              return if @current_user.blank?

              impound_claims.where(user_id: @current_user.id).not_rejected.last
            end

            def new_impound_claim
              @new_impound_claim ||= ImpoundClaim.new
            end

            # The viewer's stolen bikes they could claim this impound with
            def stolen_record_options
              claimable_bikes.map { |bike| [bike.title_string, bike.current_stolen_record_id] }
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
end
