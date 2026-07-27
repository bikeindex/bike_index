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
      # It renders no label -- wrap it in a UI::Forms::Group (kind: :content_block)
      # to get one.
      #
      # Any other keyword (id:, value:, open:, free_text:, autocomplete:,
      # placeholder:, etc.) is forwarded to `hw_combobox_tag`.
      class Component < ApplicationComponent
        def initialize(name:, options: [], src: nil, **combobox_options)
          @name = name
          @options_or_src = src || options
          @combobox_options = combobox_options
        end

        def call
          helpers.hw_combobox_tag(@name, @options_or_src, **default_id, **@combobox_options)
        end

        private

        # Without a form builder the gem ids the input with a uuid, which a Group
        # label's `for` can't target -- fall back to the name.
        def default_id
          @combobox_options[:form] ? {} : {id: @name}
        end
      end
    end
  end
end
