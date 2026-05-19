# frozen_string_literal: true

module UI
  module Combobox
    # Accessible autocomplete/combobox built on the hotwire_combobox gem.
    #
    # Pass `options` for in-memory choices or `src` for an async endpoint:
    #   - strings: %w[Trek Giant Specialized]
    #   - hashes:  [{display: "Trek", value: "1"}, ...]
    #   - records: any object with a public #to_combobox_display method
    #
    # `free_text` controls whether a value not in the options list can be
    # submitted (default: false — the input is constrained to the options).
    #
    # Any other keyword (label:, id:, value:, open:, autocomplete:,
    # placeholder:, etc.) is forwarded to `hw_combobox_tag`.
    class Component < ApplicationComponent
      def initialize(name:, options: [], src: nil, free_text: false, **combobox_options)
        @name = name
        @options_or_src = src || options
        @free_text = free_text
        @combobox_options = combobox_options
      end

      def call
        helpers.hw_combobox_tag(@name, @options_or_src, free_text: @free_text, **@combobox_options)
      end
    end
  end
end
