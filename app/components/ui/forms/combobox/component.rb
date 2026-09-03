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
      # placeholder:, etc.) is forwarded to `hw_combobox_tag`. That includes
      # `aria:` - `aria: {describedby: group.helper_text_id}` reaches the real
      # input, which is how this pairs with UI::Forms::Group's helper text.
      class Component < ApplicationComponent
        RICH_DISPLAYS = %i[inline stacked].freeze

        # Past this many, a no-JS select is worse to pick from than a textbox is to type in
        NO_JS_SELECT_MAX = 99

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
          helpers.hw_combobox_tag(@name, @options_or_src, **defaults, **combobox_attrs) do |component|
            component.customize_input(class: STACKED_INPUT_CLASSES) if stacked?
          end
        end

        # ui--forms--js-required marks it required on connect instead - rendered required,
        # it's a hidden control no browser will submit past, which without JavaScript is
        # every submission
        def combobox_attrs
          js_required? ? @combobox_options.except(:required) : @combobox_options
        end

        def js_required? = @no_js.present? && @combobox_options[:required].present?

        # What this falls back to without JavaScript. A select posts the options' own
        # values, so only a textbox needs the caller to say what to show (`no_js: {value:}`)
        def no_js_field
          return if @no_js.blank?

          render UI::Forms::NoJsField::Component.new(name: no_js_name,
            label: @combobox_options.fetch(:dialog_label) { defaults[:dialog_label] },
            value: @no_js.is_a?(Hash) ? @no_js[:value] : @combobox_options[:value],
            options: no_js_options, required: @combobox_options[:required], text: no_js_text?)
        end

        # A list can't serve free text, options fetched from an endpoint, or more of them
        # than anyone wants to scroll
        def no_js_text?
          @combobox_options[:free_text].present? || !@options_or_src.is_a?(Array) ||
            @options_or_src.length > NO_JS_SELECT_MAX
        end

        # [display, value] pairs. Nothing to offer when the options aren't ours to list
        def no_js_options
          return [] unless @options_or_src.is_a?(Array)

          @options_or_src.map do |option|
            option.is_a?(Hash) ? [option[:display], option[:value]] : [option, option]
          end
        end

        def no_js_name
          form = @combobox_options[:form]
          form ? form.field_name(@name) : @name
        end

        # Only a rich display needs the controller, or the positioning context its overlay
        # is placed against. data-js-required is what the fallback's stylesheet hides
        def wrapper_attrs
          controllers = [("ui--forms--combobox-display" if @rich_display),
            ("ui--forms--js-required" if js_required?)].compact
          data = {controller: controllers.presence&.join(" "),
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
