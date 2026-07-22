# frozen_string_literal: true

module Registrations
  module Show
    module ClaimImpound
      # "Does this look like your bike?" — lets a non-owner open an impound claim
      # against one of their stolen bikes. Mirrors the contact-owner card.
      class Component < ApplicationComponent
        def initialize(bike:, current_user: nil, owner: false)
          @bike = bike
          @current_user = current_user
          @owner = owner
        end

        def render?
          !@owner && BikeServices::Displayer.display_impound_claim?(@bike, @current_user)
        end

        private

        def claim_button_text
          translation(@bike.status_found? ? ".claim_found_bike" : ".claim_impounded_bike")
        end

        def impound_record
          @impound_record ||= @bike.current_impound_record
        end

        def impound_claim
          @impound_claim ||= ImpoundClaim.new(impound_record_id: impound_record&.id)
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
