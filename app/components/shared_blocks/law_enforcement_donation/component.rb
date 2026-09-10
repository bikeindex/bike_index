# frozen_string_literal: true

module SharedBlocks
  module LawEnforcementDonation
    # Shown once, on the sign-in after a police officer's organization is found to be
    # unpaid - session[:render_donation_request] is what raises it (Sessionable)
    class Component < ApplicationComponent
      MODAL_ID = "donateMessageModal"

      def initialize(current_user:)
        @current_user = current_user
      end

      private

      def org_name
        @current_user&.organizations&.law_enforcement&.without_invoice&.first&.name || "your organization"
      end
    end
  end
end
