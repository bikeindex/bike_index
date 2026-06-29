# frozen_string_literal: true

module Form
  module TextEditor
    # Bare Lexxy editor; pair with Form::Group (kind: :content_block) for a label -- both run through
    # the form builder, so the label's `for` matches the editor id for a given attribute. Carries
    # data-controller="lexxy", which loads the editor JS and stylesheet on demand.
    class Component < ApplicationComponent
      # value: overrides the editor's initial HTML, for editors not backed by a model attribute
      def initialize(form_builder:, attribute:, size: :default, value: nil)
        @form_builder = form_builder
        @attribute = attribute
        @size = size
        @value = value
      end

      def call
        @form_builder.lexxy_rich_textarea(@attribute, options)
      end

      private

      def options
        base = {attachments: "false", class: editor_class, data: asset_data}
        @value.nil? ? base : base.merge(value: @value)
      end

      def asset_data
        {controller: "lexxy", lexxy_stylesheet_value: helpers.stylesheet_path("lexxy")}
      end

      def editor_class
        base = "lexxy-content tw:w-full"
        (@size == :single_line) ? "#{base} lexxy-editor--compact" : base
      end
    end
  end
end
