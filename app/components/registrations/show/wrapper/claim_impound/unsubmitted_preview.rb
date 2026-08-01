# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      module ClaimImpound
        # Opened but not sent — the message is still editable
        class UnsubmittedPreview < ApplicationComponentPreview
          include PreviewScenarios

          def default
            claim_page_for(::ImpoundClaim.not_rejected.unsubmitted)
          end
        end
      end
    end
  end
end
