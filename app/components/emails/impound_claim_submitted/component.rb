# frozen_string_literal: true

module Emails
  module ImpoundClaimSubmitted
    class Component < ApplicationComponent
      def initialize(impound_claim:)
        @impound_claim = impound_claim
      end

      private

      def organization
        @impound_claim.organization
      end

      def impound_record
        @impound_claim.impound_record
      end

      def bike_claimed
        @impound_claim.bike_claimed
      end

      def bike_submitting
        @impound_claim.bike_submitting
      end

      def claim_url
        if @impound_claim.organized?
          organization_impound_claim_url(@impound_claim.id, organization_id: organization.id)
        else
          review_impound_claim_url(@impound_claim.id)
        end
      end
    end
  end
end
