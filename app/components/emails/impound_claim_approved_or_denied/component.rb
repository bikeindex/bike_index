# frozen_string_literal: true

module Emails
  module ImpoundClaimApprovedOrDenied
    class Component < ApplicationComponent
      def initialize(impound_claim:)
        @impound_claim = impound_claim
      end

      def email_sent_at
        @impound_claim&.resolved_at
      end

      private

      def organization
        @impound_claim.organization
      end

      def bike_claimed
        @impound_claim.bike_claimed
      end

      def bike_submitting
        @impound_claim.bike_submitting
      end

      def organization_message_snippet_body
        return nil unless @impound_claim.organized? && snippet_kind.present?

        MailSnippet.for_organization(organization_id: organization.id, kind: snippet_kind, time: email_sent_at)&.body
      end

      def snippet_kind
        return nil unless %w[approved denied].include?(@impound_claim.status)

        "impound_claim_#{@impound_claim.status}"
      end
    end
  end
end
