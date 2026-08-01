# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      module ClaimImpound
        # Signed out, so the claim button routes through sign-in
        class SignedOutPreview < ApplicationComponentPreview
          include PreviewScenarios

          # @param bike_id text "Bike to render — defaults to a claimable found one"
          def default(bike_id: nil)
            claim_page(bike_id: bike_id.presence || claimable_impound&.bike_id, current_user: nil)
          end
        end
      end
    end
  end
end
