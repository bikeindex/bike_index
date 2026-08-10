# frozen_string_literal: true

module UI
  module Forms
    module Combobox
      # Accessible autocomplete/combobox built on the hotwire_combobox gem.
      #
      # Pass `options` for in-memory choices or `src` for an async endpoint:
      #   - strings: %w[Trek Giant Specialized]
      #   - hashes:  [{display: "Trek", value: "1"}, ...]
      #   - records: any object with a public #to_combobox_display method
      #
      # It renders no label -- wrap it in a UI::Forms::Group block to get one.
      #
      # rich_display: shows the selected option's rich `content` on the closed
      # input via an overlay (an <input> can't render two-tone text) -- see
      # ui/forms/combobox_display_controller.js.
      #   - :inline  one line, the muted part following the display text
      #   - :stacked a muted line below the display text, on a taller input
      #
      # It always renders inside a wrapper div, so the combobox sits at the same
      # depth either way -- add your own wrapper for the parent's layout.
      #
      # Any other keyword (id:, value:, open:, free_text:, autocomplete:,
      # placeholder:, etc.) is forwarded to `hw_combobox_tag`.
      class Component < ApplicationComponent
        RICH_DISPLAYS = %i[inline stacked].freeze

        OVERLAY_CLASSES = "tw:pointer-events-none tw:absolute tw:hidden tw:text-gray-900 tw:dark:text-gray-200"
        # Centered as a block, so blurring lines up with the input's own centered text
        STACKED_OVERLAY_CLASSES = "tw:flex tw:flex-col tw:justify-center tw:overflow-hidden"
        STACKED_INPUT_CLASSES = "tw:min-h-13"

        def initialize(name:, options: [], src: nil, rich_display: nil, no_js: nil, **combobox_options)
          @name = name
          @options_or_src = src || options
          @rich_display = RICH_DISPLAYS.detect { |display| display.to_s == rich_display.to_s }
          @no_js = no_js
          @combobox_options = combobox_options
        end

        def call
          safe_join([tag.div(**wrapper_attrs) { safe_join([combobox, overlay].compact) }, no_js_field].compact)
        end

        private

        def combobox
          # customize_ (rather than the input: kwarg) appends to the gem's own classes
          helpers.hw_combobox_tag(@name, @options_or_src, **defaults, **@combobox_options) do |component|
            component.customize_input(class: STACKED_INPUT_CLASSES) if stacked?
          end
        end

        # The textbox this falls back to without JavaScript. What it posts is the caller's
        # to say - the server resolves a color by name but a cycle type by slug, neither of
        # which is reliably the display this lists. The rest is the combobox's own: which
        # field, whether it's required, and what it's called
        def no_js_field
          return if @no_js.blank?

          render UI::Forms::NoJsText::Component.new(name: no_js_name,
            label: @combobox_options.fetch(:dialog_label) { defaults[:dialog_label] },
            value: @no_js[:value], options: @no_js[:options] || [],
            required: @combobox_options[:required])
        end

        # The combobox's own field unless the fallback posts a different one
        def no_js_name
          attribute = @no_js[:name] || @name
          form = @combobox_options[:form]
          form ? form.field_name(attribute) : attribute
        end

        # Only a rich display needs the controller, or the positioning context
        # the overlay is placed against. js_required: the fallback's stylesheet hides
        # this, so the textbox is the only control when there's no JavaScript
        def wrapper_attrs
          data = {controller: ("ui--forms--combobox-display" if @rich_display),
                  js_required: (true if @no_js.present?)}.compact
          {class: ("tw:relative" if @rich_display), data:}.compact
        end

        def overlay
          return unless @rich_display

          tag.div(class: overlay_classes, data: {"ui--forms--combobox-display-target": "overlay"})
        end

        def stacked?
          @rich_display == :stacked
        end

        def overlay_classes
          [OVERLAY_CLASSES, stacked? ? STACKED_OVERLAY_CLASSES : "tw:truncate"].join(" ")
        end

        # id: without a form builder the gem ids the input with a uuid, which a Group
        # label's `for` can't target. dialog_label: names the input in the full screen
        # dialog the gem opens on mobile, which hides the Group's label -- pass it
        # explicitly when that label isn't the humanized name.
        def defaults
          {dialog_label: @name.to_s.humanize, id: (@name unless @combobox_options[:form])}.compact
        end
      end
    end
  end
end
