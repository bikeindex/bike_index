# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      module ClaimImpound
        # Sent, and waiting on the finder
        class SubmittedPreview < ApplicationComponentPreview
          include PreviewScenarios

          def default
            claim_page_for(::ImpoundClaim.not_rejected.submitted.where.not(status: ::ImpoundClaim.successful_statuses))
          end
        end
      end
    end
  end
end
