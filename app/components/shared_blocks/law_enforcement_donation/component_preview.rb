# frozen_string_literal: true

module SharedBlocks
  module LawEnforcementDonation
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(Component.new(current_user: lookbook_user))
      end

      # No unpaid law enforcement organization, so the nonprofit note falls back
      def without_an_organization
        render(Component.new(current_user: ::User.new(name: "Officer Friendly")))
      end
    end
  end
end
