# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      module ClaimImpound
        # Signed in with nothing to claim the found bike with
        class WithoutStolenRegistrationPreview < ApplicationComponentPreview
          include PreviewScenarios

          # @param bike_id text "Bike to render — defaults to a claimable found one"
          def default(bike_id: nil)
            claim_page(bike_id:, current_user: user_without_stolen_bike)
          end
        end
      end
    end
  end
end
