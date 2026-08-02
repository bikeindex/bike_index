# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      module ClaimImpound
        # The viewer has a stolen registration to claim the found bike with
        class WithStolenRegistrationPreview < ApplicationComponentPreview
          include PreviewScenarios

          # @param bike_id text "Bike to render — defaults to a claimable found one"
          def default(bike_id: nil)
            claim_page(bike_id:, current_user: unclaimed_viewer)
          end
        end
      end
    end
  end
end
