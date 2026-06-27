# frozen_string_literal: true

module Form
  module TextEditor
    # Lexxy rich-text editor bound to a form attribute. Lexxy must be loaded on the page
    # (data-controller="lexxy"). The associated label gives the editor's text box its accessible
    # name. Pass size: :small for the compact variant (see lexxy_overrides.css), and multi_line:
    # true to allow line breaks (default false submits a single line).
    class Component < ApplicationComponent
      def initialize(form_builder:, attribute:, label: nil, size: :normal, multi_line: false)
        @form_builder = form_builder
        @attribute = attribute
        @label = label.nil? ? attribute.to_s.humanize : label
        @size = size
        @multi_line = multi_line
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

      def editor_class
        base = "lexxy-content tw:w-full"
        (@size == :small) ? "#{base} lexxy-editor--compact" : base
      end
    end
  end
end
