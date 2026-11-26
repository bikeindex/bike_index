# frozen_string_literal: true

module UI
  module Code
    module Inline
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants

        def default
          render(UI::Code::Inline::Component.new(text: "GULLY-1987-XX"))
        end

        def small
          render(UI::Code::Inline::Component.new(text: "GULLY-1987-XX", small: true))
        end

        def without_word_break
          render(UI::Code::Inline::Component.new(text: "GULLY-1987-XX", word_break: false))
        end

        # @!endgroup
      end
    end
  end
end
