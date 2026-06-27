# frozen_string_literal: true

module Form
  module TextEditor
    # Single-line Lexxy rich-text editor bound to a form attribute. Lexxy must be loaded on the
    # page (data-controller="lexxy"). The associated label gives the editor's text box its
    # accessible name.
    class Component < ApplicationComponent
      def initialize(form_builder:, attribute:, label: nil)
        @form_builder = form_builder
        @attribute = attribute
        @label = label.nil? ? attribute.to_s.humanize : label
      end

      private

      def field_name
        "#{@form_builder.object_name}[#{@attribute}]"
      end

      def field_id
        "#{@form_builder.object_name}_#{@attribute}"
      end

      def value
        @form_builder.object.public_send(@attribute)
      end
    end
  end
end
