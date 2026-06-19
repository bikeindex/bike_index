# frozen_string_literal: true

module PageBlock
  module Footer
    class ComponentPreview < ApplicationComponentPreview
      # @!group Footer

      def default
        render(PageBlock::Footer::Component.new(controller_namespace: nil,
          controller_name: "welcome", current_user: nil, params: passed_params))
      end

      def signed_in
        render(PageBlock::Footer::Component.new(controller_namespace: nil,
          controller_name: "welcome", current_user: lookbook_user, params: passed_params))
      end
      # @endgroup

      private

      def passed_params(hash = {})
        ActionController::Parameters.new(hash)
      end
    end
  end
end
