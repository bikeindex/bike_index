# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      module ClaimImpound
        # Viewing the stolen registration a claim was opened with, which points at the
        # impounded one rather than offering a claim of its own
        class SubmittedWithThisBikePreview < ApplicationComponentPreview
          include PreviewScenarios

          def default
            impound_claim = ::ImpoundClaim.not_rejected.where.not(bike_submitting_id: nil).last
            return missing_notice("an impound claim") if impound_claim.blank?

            claim_page(bike_id: impound_claim.bike_submitting_id, current_user: impound_claim.user)
          end
        end
      end
    end
  end
end
