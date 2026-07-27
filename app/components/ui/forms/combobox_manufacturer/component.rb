# frozen_string_literal: true

module UI
  module Forms
    module ComboboxManufacturer
      # UI::Forms::Combobox preconfigured for picking a Manufacturer.
      #
      # Defaults `name` to :manufacturer_id, autocompleting against the Autocomplete
      # index (Search::ComboboxController#manufacturers) rather than rendering every
      # manufacturer; pass `frame_maker: true` to limit it to manufacturers that make
      # frames. Every other keyword (form:, label:, value:, required:, placeholder:,
      # etc.) is forwarded to UI::Forms::Combobox::Component.
      #
      # A manufacturer that isn't in the index is entered as free text through the
      # "Unknown manufacturer" option, which BParam resolves to Manufacturer.other plus
      # manufacturer_other. Pass `no_manufacturer_other: true` where only an indexed
      # manufacturer is acceptable.
      class Component < ApplicationComponent
        def initialize(name: :manufacturer_id, frame_maker: false, no_manufacturer_other: false, **combobox_options)
          @name = name
          @frame_maker = frame_maker
          @no_manufacturer_other = no_manufacturer_other
          @combobox_options = combobox_options
        end

        def call
          render UI::Forms::Combobox::Component.new(**combobox_arguments)
        end

        private

        def combobox_arguments
          {
            name: @name,
            label: Manufacturer.model_name.human,
            src: search_combobox_manufacturers_path(frame_maker: @frame_maker.presence,
              no_manufacturer_other: @no_manufacturer_other.presence),
            **free_text_options,
            **@combobox_options,
            **manufacturer_other_options
          }
        end

        def free_text_options
          @no_manufacturer_other ? {} : {free_text: true}
        end

        # An async combobox displays its initial value via the form object's
        # manufacturer. Manufacturer.other displays as "Other", so replace the form with
        # its field name and the free text, which the combobox displays as-is.
        def manufacturer_other_options
          return {} if @no_manufacturer_other

          form = @combobox_options[:form]
          return {} unless form&.object.try(:manufacturer)&.other?

          {form: nil, name: form.field_name(@name), id: form.field_id(@name), value: form.object.manufacturer_other}
        end
      end
    end
  end
end
