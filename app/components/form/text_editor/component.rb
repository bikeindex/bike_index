# frozen_string_literal: true

module Form
  module TextEditor
    # Bare Lexxy rich-text editor (just the text box) bound to a form attribute -- wrap it in
    # Form::Group (kind: :content_block) to render it with a label. The editor's id follows the same
    # convention Form::Group's label uses for `for`, so they associate (the editor's accessible
    # name) when given the same attribute. By default it carries data-controller="lexxy", which
    # lazily loads the Lexxy JS bundle and stylesheet; pass skip_assets: true on the extra editors
    # when several share a page (one editor's controller upgrades them all). Pass size: :small for
    # the compact variant (see lexxy_overrides.css), and multi_line: true to allow line breaks
    # (default false submits a single line).
    class Component < ApplicationComponent
      def initialize(form_builder:, attribute:, size: :normal, multi_line: false, skip_assets: false)
        @form_builder = form_builder
        @attribute = attribute
        @size = size
        @multi_line = multi_line
        @skip_assets = skip_assets
      end

      def call
        options = {id: field_id, "multi-line": @multi_line.to_s, attachments: "false", class: editor_class}
        options[:data] = asset_data unless @skip_assets
        helpers.lexxy_rich_textarea_tag(field_name, value, options)
      end

      private

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
        (@size == :small) ? "#{base} lexxy-editor--compact" : base
      end
    end
  end
end
