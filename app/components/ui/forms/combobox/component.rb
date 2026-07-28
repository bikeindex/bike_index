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
      # ui/forms/combobox_display_controller.js. Pass a class string to also
      # put it on the wrapper (e.g. "tw:flex-1"). Pass :stacked when the option
      # content is a primary line with a muted line below it, rather than one
      # line of two-tone text -- the input grows to fit both.
      #
      # Any other keyword (id:, value:, open:, free_text:, autocomplete:,
      # placeholder:, etc.) is forwarded to `hw_combobox_tag`.
      class Component < ApplicationComponent
        OVERLAY_CLASSES = "tw:pointer-events-none tw:absolute tw:hidden tw:text-gray-900 tw:dark:text-gray-200"
        # Centered as a block, so blurring lines up with the input's own centered text
        STACKED_OVERLAY_CLASSES = "tw:flex tw:flex-col tw:justify-center tw:overflow-hidden"
        STACKED_INPUT_CLASSES = "tw:min-h-13"

        def initialize(name:, options: [], src: nil, rich_display: false, **combobox_options)
          @name = name
          @options_or_src = src || options
          @rich_display = rich_display
          @combobox_options = combobox_options
        end

        def call
          # customize_ (rather than the input: kwarg) appends to the gem's own classes
          combobox = helpers.hw_combobox_tag(@name, @options_or_src, **defaults, **@combobox_options) do |component|
            component.customize_input(class: STACKED_INPUT_CLASSES) if stacked?
          end
          return combobox unless @rich_display

          tag.div(class: ["tw:relative", (@rich_display if @rich_display.is_a?(String))],
            data: {controller: "ui--forms--combobox-display"}) do
            combobox + tag.div(class: overlay_classes, data: {"ui--forms--combobox-display-target": "overlay"})
          end
        end

        private

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
