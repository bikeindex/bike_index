# frozen_string_literal: true

module SharedBlocks
  module Footer
    class ComponentPreview < ApplicationComponentPreview
      # @!group Footer

      # @display legacy_stylesheet true
      def default
        render(SharedBlocks::Footer::Component.new(current_user: nil, color_scheme: "system", skip_facebook: false))
      end

      # @display legacy_stylesheet true
      def signed_in
        render(SharedBlocks::Footer::Component.new(current_user: lookbook_user, color_scheme: "system", skip_facebook: false))
      end
      # @endgroup
    end
  end
end
