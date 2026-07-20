# frozen_string_literal: true

module UI
  module Forms
    module ComboboxManufacturer
      # UI::Forms::Combobox preconfigured for picking a Manufacturer.
      #
      # Defaults `name` to :manufacturer_id and the options to every manufacturer;
      # pass `frame_maker: true` to limit the list to frame makers, or a `manufacturers`
      # relation to set it explicitly. Every other keyword (form:, label:, value:,
      # required:, include_blank:, placeholder:, etc.) is forwarded to
      # UI::Forms::Combobox::Component.
      class Component < ApplicationComponent
        def initialize(name: :manufacturer_id, frame_maker: false, manufacturers: nil, **combobox_options)
          @name = name
          @manufacturers = manufacturers || (frame_maker ? Manufacturer.frame_makers : Manufacturer.all)
          @combobox_options = combobox_options
        end

        def call
          render UI::Forms::Combobox::Component.new(
            name: @name,
            label: Manufacturer.model_name.human,
            options: @manufacturers.pluck(:name, :id),
            **@combobox_options
          )
        end
      end
    end
  end
end
