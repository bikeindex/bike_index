# frozen_string_literal: true

module Form
  module TextEditor
    # Bare Lexxy editor; pair with Form::Group (kind: :content_block) for a label -- their ids line
    # up given the same attribute. Carries data-controller="lexxy" (loads the JS + CSS) unless
    # skip_assets is set on extra editors sharing a page.
    class Component < ApplicationComponent
      def initialize(form_builder:, attribute:, size: :default, skip_assets: false)
        @form_builder = form_builder
        @attribute = attribute
        @size = size
        @skip_assets = skip_assets
      end

      def call
        helpers.lexxy_rich_textarea_tag(field_name, value, options)
      end

      private

      def options
        base = {id: field_id, "multi-line": (@size != :single_line).to_s, attachments: "false", class: editor_class}
        @skip_assets ? base : base.merge(data: asset_data)
      end

      def asset_data
        {controller: "lexxy", lexxy_stylesheet_value: helpers.stylesheet_path("lexxy")}
      end

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
        (@size == :single_line) ? "#{base} lexxy-editor--compact" : base
      end
    end
  end
end
