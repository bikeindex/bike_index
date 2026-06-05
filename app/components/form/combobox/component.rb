# frozen_string_literal: true

module Form
  module Combobox
    # Accessible autocomplete/combobox built on the hotwire_combobox gem.
    #
    # Pass `options` for in-memory choices or `src` for an async endpoint:
    #   - strings: %w[Trek Giant Specialized]
    #   - hashes:  [{display: "Trek", value: "1"}, ...]
    #   - records: any object with a public #to_combobox_display method
    #
    # Any other keyword (label:, id:, value:, open:, free_text:, autocomplete:,
    # placeholder:, etc.) is forwarded to `hw_combobox_tag`.
    class Component < ApplicationComponent
      def initialize(name:, options: [], src: nil, label_class: nil, **combobox_options)
        @name = name
        @options_or_src = src || options
        @label_class = label_class
        @combobox_options = combobox_options
      end

      def call
        helpers.hw_combobox_tag(@name, @options_or_src, **@combobox_options) do |combobox|
          combobox.customize_label(class: @label_class) if @label_class
        end
      end
    end
  end
end
