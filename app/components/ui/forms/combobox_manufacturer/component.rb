# frozen_string_literal: true

module UI
  module Forms
    module ComboboxManufacturer
      # UI::Forms::Combobox preconfigured for picking a Manufacturer.
      #
      # Defaults `name` to :manufacturer_id, autocompleting against the Autocomplete
      # index (Search::ComboboxController#manufacturers) rather than rendering every
      # manufacturer; pass `frame_maker: true` to limit it to manufacturers that make
      # frames. Every other keyword except `placeholder:` (form:, value:, required:,
      # etc.) is forwarded to UI::Forms::Combobox::Component, which renders no label --
      # wrap it in a UI::Forms::Group block to get one.
      #
      # A manufacturer that isn't in the index is entered as free text through the
      # "Unknown manufacturer" option, which BParam resolves to Manufacturer.other plus
      # manufacturer_other. Pass `no_manufacturer_other: true` where only an indexed
      # manufacturer is acceptable.
      class Component < ApplicationComponent
        # One is sampled for the placeholder, to show what the field autocompletes
        PLACEHOLDER_NAMES = ["Trek", "Surly", "Giant Bikes", "Rad Power Bikes", "Cannondale",
          "Lectric eBikes", "Aventón", "Canyon", "Orbea", "Juliana"].freeze

        def initialize(name: :manufacturer_id, frame_maker: false, no_manufacturer_other: false, no_js: false, **combobox_options)
          @name = name
          @frame_maker = frame_maker
          @no_manufacturer_other = no_manufacturer_other
          @no_js = no_js
          @combobox_options = combobox_options
        end

        def call
          render UI::Forms::Combobox::Component.new(**combobox_arguments)
        end

        private

        # placeholder comes after the caller's options: every manufacturer field reads
        # the same, so it isn't overridable
        def combobox_arguments
          {
            name: @name,
            src: search_combobox_manufacturers_path(**src_params),
            free_text: !@no_manufacturer_other,
            **@combobox_options,
            placeholder: translation(".placeholder", name: PLACEHOLDER_NAMES.sample),
            **manufacturer_other_options,
            **no_js_options
          }
        end

        # Autocompleted against an index no textbox can reach, so the fallback offers no
        # options - an unknown name becomes manufacturer_other, like the combobox's free text
        def no_js_options
          return {} unless @no_js

          {no_js: {value: manufacturer_display}}
        end

        def manufacturer_display
          return if manufacturer.blank?

          manufacturer.other? ? @combobox_options[:form].object.manufacturer_other : manufacturer.name
        end

        # BParam#manufacturer is a friendly_find, so a query every time - and both the
        # fallback's value and the free-text swap below want it
        def manufacturer
          return @manufacturer if defined?(@manufacturer)

          @manufacturer = @combobox_options[:form]&.object.try(:manufacturer)
        end

        def src_params
          {frame_maker: @frame_maker, no_manufacturer_other: @no_manufacturer_other}.select { |_, value| value }
        end

        # An async combobox displays its initial value via the form object's
        # manufacturer. Manufacturer.other displays as "Other", so replace the form with
        # its field name and the free text, which the combobox displays as-is.
        def manufacturer_other_options
          return {} if @no_manufacturer_other || !manufacturer&.other?

          form = @combobox_options[:form]
          {form: nil, name: form.field_name(@name), id: form.field_id(@name), value: form.object.manufacturer_other}
        end
      end
    end
  end
end
