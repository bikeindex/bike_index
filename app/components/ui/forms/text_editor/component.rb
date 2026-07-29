# frozen_string_literal: true

module UI
  module Forms
    module TextEditor
      # Bare Lexxy editor; pair with a UI::Forms::Group block (and standalone: false) for a label.
      # Carries data-controller="ui--forms--text-editor", which loads the editor JS and stylesheet on demand.
      class Component < ApplicationComponent
        SIZE = %i[default single_line].freeze

        # toolbar_buttons: shows only a subset -- the rest are hidden via lexxy_overrides.css.
        TOOLBAR_BUTTONS = %i[bold italic strikethrough underline format highlight link quote code
          unordered_list ordered_list table divider undo redo].freeze

        # The compact single-line editor gets a trimmed toolbar unless the caller overrides it.
        SINGLE_LINE_TOOLBAR_BUTTONS = %i[bold italic link undo redo].freeze

        def initialize(form_builder:, attribute:, size: :default, toolbar_buttons: nil, value: nil, standalone: true)
          raise ArgumentError, "size must be one of #{SIZE.inspect}, got #{size.inspect}" unless SIZE.include?(size)

          @form_builder = form_builder
          @attribute = attribute
          @size = size
          @value = value
          @standalone = standalone
          @toolbar_buttons = toolbar_buttons || (SINGLE_LINE_TOOLBAR_BUTTONS if size == :single_line)

          unknown = (@toolbar_buttons || []) - TOOLBAR_BUTTONS
          raise ArgumentError, "unknown toolbar_buttons: #{unknown.inspect}" if unknown.any?
        end

        def call
          @form_builder.lexxy_rich_textarea(@attribute, options)
        end

        private

        def options
          {attachments: "false", class: editor_class, data: asset_data}
            .merge(@value.nil? ? {} : {value: @value})
            .merge(@standalone ? {aria: {label: @attribute.to_s.humanize}} : {})
        end

        def asset_data
          {controller: "ui--forms--text-editor", action: "click->ui--forms--text-editor#focusEditor",
           "ui--forms--text-editor-stylesheet-value": helpers.stylesheet_path("lexxy")}
        end

        def editor_class
          [
            "lexxy-content tw:w-full",
            ("lexxy-editor--compact" if @size == :single_line),
            *hidden_button_classes
          ].compact.join(" ")
        end

        def hidden_button_classes
          return [] if @toolbar_buttons.nil?

          (TOOLBAR_BUTTONS - @toolbar_buttons).map { "lexxy-editor--hide-#{it.to_s.tr("_", "-")}" }
        end
      end
    end
  end
end
