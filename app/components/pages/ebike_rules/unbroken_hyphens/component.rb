# frozen_string_literal: true

module Pages
  module EbikeRules
    module UnbrokenHyphens
      # Plain text whose hyphenated words never wrap at the hyphen, which splits "e-bike" across lines
      class Component < ApplicationComponent
        def initialize(text:)
          @text = text
        end

        def call
          safe_join(@text.split(/(\S+-\S+)/).map { it.include?("-") ? tag.span(it, class: "tw:whitespace-nowrap") : it })
        end
      end
    end
  end
end
