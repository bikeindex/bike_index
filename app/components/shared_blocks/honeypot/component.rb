# frozen_string_literal: true

module SharedBlocks
  module Honeypot
    class Component < ApplicationComponent
      def initialize(form_builder: nil)
        @form_builder = form_builder
      end

      def call
        # A nil object name posts the field bare, the way text_field_tag does
        builder = @form_builder || BikeIndexFormBuilder.new(nil, nil, helpers, {})

        tag.div(class: "tw:hidden") do
          safe_join([builder.label(:additional, "Additional information"),
            builder.text_field(:additional, tabindex: -1, autocomplete: "off")])
        end
      end
    end
  end
end
