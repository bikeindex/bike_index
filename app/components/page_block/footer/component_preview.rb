# frozen_string_literal: true

module PageBlock
  module Footer
    class ComponentPreview < ApplicationComponentPreview
      # @!group Footer

      # @display legacy_stylesheet true
      def default
        render(PageBlock::Footer::Component.new(current_user: nil, skip_facebook: false))
      end

      # @display legacy_stylesheet true
      def signed_in
        render(PageBlock::Footer::Component.new(current_user: lookbook_user, skip_facebook: false))
      end
      # @endgroup
    end
  end
end
