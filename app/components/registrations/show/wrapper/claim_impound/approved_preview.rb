# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      module ClaimImpound
        # Answered, so the card carries the outcome rather than a form
        class ApprovedPreview < ApplicationComponentPreview
          include PreviewScenarios

          def default
            claim_page_for(::ImpoundClaim.submitted.where(status: ::ImpoundClaim.successful_statuses))
          end
        end
      end
    end
  end
end
