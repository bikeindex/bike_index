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
      # to get one. Pass `dialog_label:` when the Group's label isn't the humanized
      # name, since the mobile dialog covers the page.
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
          helpers.hw_combobox_tag(@name, @options_or_src, **defaults, **@combobox_options)
        end

        private

        # id: without a form builder the gem ids the input with a uuid, which a Group
        # label's `for` can't target. dialog_label: names the input inside the full
        # screen dialog the gem opens on mobile, which hides the Group's label.
        def defaults
          {dialog_label: @name.to_s.humanize, **(@combobox_options[:form] ? {} : {id: @name})}
        end
      end
    end
  end
end
