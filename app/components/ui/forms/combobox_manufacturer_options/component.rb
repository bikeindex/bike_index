# frozen_string_literal: true

module UI
  module Forms
    module ComboboxManufacturerOptions
      # The async options for UI::Forms::ComboboxManufacturer::Component - autocomplete
      # matches (ordered by manufacturer priority, then alphabetically), plus the
      # synthetic "Unknown manufacturer" option that free text is entered through.
      # Sibling to the form control; this is the turbo-stream response backing it.
      class Component < ApplicationComponent
        def initialize(matches:, next_page:, first_page:, q: nil, no_manufacturer_other: false)
          @matches = matches
          @first_page = first_page
          @next_page = next_page
          @q = q.presence
          @no_manufacturer_other = no_manufacturer_other
        end

        def call
          helpers.hw_async_combobox_options(option_data, next_page: @next_page)
        end

        private

        def option_data
          data = manufacturer_matches.map do |match|
            {id: "manufacturer_#{match["id"]}", value: match["id"], display: match["text"]}
          end
          data << unknown_manufacturer_option if unknown_manufacturer?
          data
        end

        # Manufacturer.other is never selectable - it's what free text resolves to
        def manufacturer_matches
          @manufacturer_matches ||= begin
            other_id = Manufacturer.other.id
            @matches.reject { |match| match["id"] == other_id }
          end
        end

        def unknown_manufacturer?
          return false if @no_manufacturer_other || @q.blank? || !@first_page

          manufacturer_matches.none? { |match| match["text"].casecmp?(@q) }
        end

        def unknown_manufacturer_option
          content = safe_join([
            tag.span(translation(".unknown_manufacturer"), class: "tw:text-gray-500 tw:dark:text-gray-400"), " ",
            tag.span(@q)
          ])

          {id: "hw_unknown_manufacturer_option", value: @q, display: @q, content:}
        end
      end
    end
  end
end
