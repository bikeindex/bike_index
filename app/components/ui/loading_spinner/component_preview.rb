# frozen_string_literal: true

module UI
  module LoadingSpinner
    class ComponentPreview < ApplicationComponentPreview
      # @!group Sizes
      def sm
        render(UI::LoadingSpinner::Component.new(size: :sm))
      end

      def md
        render(UI::LoadingSpinner::Component.new(size: :md))
      end

      def md_with_text
        render(UI::LoadingSpinner::Component.new(text: "Loading results...", size: :md))
      end

      # @!endgroup
    end
  end
end
